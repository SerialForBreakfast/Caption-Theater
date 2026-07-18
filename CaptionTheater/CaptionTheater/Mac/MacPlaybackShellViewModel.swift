//
//  MacPlaybackShellViewModel.swift
//  CaptionTheater
//
//  Native macOS playback shell model for offline HLS demo playback.
//

#if os(macOS)
import AVFoundation
import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class MacPlaybackShellViewModel {

    let player: AVPlayer

    private var timeObserverToken: Any?
    private var keyPathObservations: [NSKeyValueObservation] = []
    private var itemStatusObservation: NSKeyValueObservation?
    private let legibleCaptionSink = CaptionTheaterLegibleCaptionSink()
    private var captionLegibleOutput: AVPlayerItemLegibleOutput?
    private weak var legibleOutputHostItem: AVPlayerItem?

    private(set) var durationSeconds: Double = 0
    private(set) var currentSeconds: Double = 0
    private(set) var timeControlStatus: AVPlayer.TimeControlStatus = .paused
    private(set) var captionScrollingCueEntries: [CaptionTheaterScrollingCueEntry] = []
    private(set) var playbackFailureDescription: String?
    private(set) var pictureAspectRatioWidthOverHeight: Double?
    private(set) var presentationAspectGeneration: Int = 0

    var captionTheaterTopPinnedLayoutEnabled = true

    var sourceAspectForWindowPreset: CGFloat? {
        pictureAspectRatioWidthOverHeight.map { CGFloat($0) }
    }

    var presentationAspectSummary: String {
        guard let pictureAspectRatioWidthOverHeight else {
            return "Picture aspect: loading..."
        }
        return String(format: "Picture aspect (w÷h): %.3f", pictureAspectRatioWidthOverHeight)
    }

    init(url: URL) {
        player = AVPlayer(url: url)
        timeControlStatus = player.timeControlStatus

        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                let seconds = time.seconds
                self.currentSeconds = seconds.isFinite ? seconds : 0
            }
        }

        wireLegibleCaptionSinkHandlers()
        installPlaybackObservers()
        player.play()

        Task { await loadDuration(for: url) }
        Task { await loadPresentationAspect(for: url) }
    }

    func layoutGeometry(containerSize: CGSize) -> CaptionTheaterLayoutGeometry? {
        guard let aspect = pictureAspectRatioWidthOverHeight else {
            return nil
        }

        let inputs = CaptionTheaterLayoutInputs(
            containerSize: containerSize,
            pictureAspectRatioWidthOverHeight: aspect
        )

        let mode: CaptionTheaterLayoutPresentationMode =
            captionTheaterTopPinnedLayoutEnabled ? .captionTheaterAspectFitTopPinned : .nativeAspectFitCentered
        return CaptionTheaterLayoutEngine().geometry(for: inputs, mode: mode)
    }

    func refreshCaptionTheaterLegiblePipeline(reason: String) {
        Task { @MainActor in
            await attachCaptionTheaterLegibleOutputIfNeeded(reason: reason)
        }
    }

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func restartPlayback() {
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                captionScrollingCueEntries = []
                player.play()
            }
        }
    }

    func detachPlaybackObservers() {
        detachCaptionTheaterLegibleOutput(reason: "detachPlaybackObservers")
        captionScrollingCueEntries = []

        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        for observation in keyPathObservations {
            observation.invalidate()
        }
        keyPathObservations.removeAll()
    }

    private func wireLegibleCaptionSinkHandlers() {
        legibleCaptionSink.onAttributedStrings = { [weak self] strings, itemTime in
            Task { @MainActor in
                self?.applyLegibleAttributedStrings(strings, itemTime: itemTime)
            }
        }
        legibleCaptionSink.onOutputSequenceFlushed = { [weak self] in
            Task { @MainActor in
                self?.captionScrollingCueEntries = []
            }
        }
    }

    private func applyLegibleAttributedStrings(_ strings: [NSAttributedString], itemTime _: CMTime) {
        guard !strings.isEmpty else {
            return
        }

        var plain = CaptionTheaterLegibleCaptionFormatting.plainCaptionText(from: strings)
        if plain.isEmpty {
            plain = CaptionTheaterLegibleCaptionFormatting.resolvedPlainCaptionText(from: strings)
        }
        guard !plain.isEmpty else {
            return
        }

        guard let updated = CaptionTheaterScrollingCaptionPolicy.entriesByPrependingDistinctCue(
            previousEntries: captionScrollingCueEntries,
            incomingPlain: plain
        ) else {
            return
        }

        captionScrollingCueEntries = Array(updated)
    }

    private func detachCaptionTheaterLegibleOutput(reason _: String) {
        guard let output = captionLegibleOutput else {
            return
        }
        legibleOutputHostItem?.remove(output)
        captionLegibleOutput = nil
        legibleOutputHostItem = nil
        legibleCaptionSink.resetLegibleDeliveryTelemetry()
    }

    private func attachCaptionTheaterLegibleOutputIfNeeded(reason _: String) async {
        guard captionTheaterTopPinnedLayoutEnabled else {
            detachCaptionTheaterLegibleOutput(reason: "top pinned layout off")
            captionScrollingCueEntries = []
            return
        }

        guard let item = player.currentItem, item.status == .readyToPlay else {
            return
        }

        if captionLegibleOutput != nil, legibleOutputHostItem === item {
            try? await selectCaptionTheaterLegibleMediaOption(for: item)
            return
        }

        detachCaptionTheaterLegibleOutput(reason: "reattach")

        let output = AVPlayerItemLegibleOutput()
        output.suppressesPlayerRendering = true
        output.textStylingResolution = .default
        output.setDelegate(legibleCaptionSink, queue: .main)
        item.add(output)
        captionLegibleOutput = output
        legibleOutputHostItem = item

        do {
            try await selectCaptionTheaterLegibleMediaOption(for: item)
        } catch {
            item.remove(output)
            captionLegibleOutput = nil
            legibleOutputHostItem = nil
        }
    }

    private func selectCaptionTheaterLegibleMediaOption(for item: AVPlayerItem) async throws {
        guard let group = try await item.asset.loadMediaSelectionGroup(for: .legible),
              let option = group.defaultOption ?? group.options.first
        else {
            return
        }

        item.select(option, in: group)
    }

    private func installPlaybackObservers() {
        keyPathObservations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            Task { @MainActor in
                self.timeControlStatus = player.timeControlStatus
            }
        })

        keyPathObservations.append(player.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            Task { @MainActor in
                self.detachCaptionTheaterLegibleOutput(reason: "currentItem changed")
                self.observeCurrentItemStatus(player.currentItem)
            }
        })

        observeCurrentItemStatus(player.currentItem)
    }

    private func observeCurrentItemStatus(_ item: AVPlayerItem?) {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        guard let item else {
            return
        }

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self.player.play()
                    self.refreshCaptionTheaterLegiblePipeline(reason: "readyToPlay")
                    Task { await self.reloadPresentationAspectFromCurrentItemAsset() }
                case .failed:
                    self.playbackFailureDescription = item.error?.localizedDescription ?? "Playback failed"
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func reloadPresentationAspectFromCurrentItemAsset() async {
        guard let asset = player.currentItem?.asset else {
            return
        }
        await loadPresentationAspect(from: asset)
    }

    private func loadDuration(for url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            durationSeconds = seconds.isFinite && seconds > 0 ? seconds : 0
        } catch {
            durationSeconds = 0
        }
    }

    private func loadPresentationAspect(for url: URL) async {
        let asset = AVURLAsset(url: url)
        await loadPresentationAspect(from: asset)
    }

    private func loadPresentationAspect(from asset: AVAsset) async {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let displaySize = naturalSize.applying(transform)
            let width = abs(Double(displaySize.width))
            let height = abs(Double(displaySize.height))
            guard height > 0 else {
                return
            }

            pictureAspectRatioWidthOverHeight = width / height
            MacPlaybackStateStore.shared.sourceAspectForWindowPreset = CGFloat(width / height)
            presentationAspectGeneration += 1
        } catch {
            pictureAspectRatioWidthOverHeight = nil
        }
    }
}
#endif
