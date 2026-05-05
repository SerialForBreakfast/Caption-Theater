//
//  CaptionTheaterPlaybackShellViewModel.swift
//  CaptionTheater
//
//  Owns AVPlayer observation and MVP layout inputs for the tvOS playback shell (CT-0501 / CT-0502 / CT-0303 slice).
//

import AVFoundation
import CoreGraphics
import Foundation
import Observation

/// Playback shell state bridge between `AVPlayer` timers and SwiftUI on the main actor.
///
/// **Concurrency:** All methods and properties are main-actor isolated; UI reads timers and issues
/// transport commands on the main actor. Call ``detachPlaybackObservers()`` from `onDisappear` so
/// periodic observers never outlive the hosting view.
///
/// **Playback observation:** Key-path observers attach to ``AVPlayer`` / ``AVPlayerItem`` for logging and
/// explicit ``AVPlayer/play()`` when the item reaches ``AVPlayerItem/Status-swift.enum/readyToPlay``. Invalidate
/// via ``detachPlaybackObservers()`` so KVO tokens never leak.
///
/// Scenario fixtures load synchronously from ``Bundle/main`` on the main actor because files are tiny;
/// larger manifests belong in background tasks once parsing grows beyond microsecond budgets.
@MainActor
@Observable
final class CaptionTheaterPlaybackShellViewModel {

    /// Sample clip player for fixture playback.
    let player: AVPlayer

    private var timeObserverToken: Any?

    /// Key-path observations for player/item lifecycle logging.
    private var keyPathObservations: [NSKeyValueObservation] = []

    /// Observation for the active item’s ``AVPlayerItem/status`` (replaced when ``AVPlayer/currentItem`` changes).
    private var itemStatusObservation: NSKeyValueObservation?

    /// Parsed duration in seconds; zero until loading finishes or if unknown.
    private(set) var durationSeconds: Double = 0

    /// Current playhead in seconds (updates periodically while presented).
    private(set) var currentSeconds: Double = 0

    /// Bundled inspector scenarios feeding ``CaptionTheaterPlaybackEvidenceAssembler``.
    var scenarioKind: CaptionTheaterPlaybackScenarioKind = .eligibleUltraWideLetterbox

    /// Parsed inspector pack for ``scenarioKind``, except manual legacy mode (nil by design).
    private(set) var scenarioPack: CaptionTheaterPlaybackScenarioPack?

    /// Surface fixture-loading failures from ``CaptionTheaterPlaybackScenarioKind/loadPack(bundle:)``.
    private(set) var scenarioLoadError: String?

    /// User accepted the Caption Theater prompt while enabling the feature toggle.
    var captionTheaterOptInAccepted: Bool = false

    /// Demo-only: force WebVTT subtitle state for eligibility recordings.
    var demoAssumeWebVTTSelected: Bool = false

    /// Demo-only: force safe letterbox viewport classification.
    var demoAssumeSafeLetterboxViewport: Bool = false

    /// Picture aspect ratio (width ÷ height) from the primary video track (display dimensions); drives ``CaptionTheaterLayoutEngine``.
    private(set) var pictureAspectRatioWidthOverHeight: Double?

    /// When true, ``CaptionTheaterLayoutEngine`` uses ``CaptionTheaterLayoutPresentationMode/captionTheaterAspectFitTopPinned`` (MVP negative-space captions).
    var captionTheaterTopPinnedLayoutEnabled: Bool = false

    /// Human-readable failure when ``AVPlayerItem`` enters the failed state (for fullscreen error UI).
    private(set) var playbackFailureDescription: String?

    /// `true` once encoded picture aspect exceeds ``CaptionTheaterPlaybackUILayout/ultrawideAspectRatioThresholdWidthOverHeight``.
    var isUltraWideEncodedPicture: Bool {
        guard let ar = pictureAspectRatioWidthOverHeight else {
            return false
        }
        return ar > Double(CaptionTheaterPlaybackUILayout.ultrawideAspectRatioThresholdWidthOverHeight)
    }

    /// Human-readable picture aspect for debug HUD (nil while loading).
    var presentationAspectSummary: String {
        guard let ar = pictureAspectRatioWidthOverHeight else {
            return "Picture aspect: loading…"
        }
        return String(format: "Picture aspect (w÷h): %.3f", ar)
    }

    init(url: URL) {
        CaptionTheaterPlaybackLogger.playbackFlow("CaptionTheaterPlaybackShellViewModel init url=\(url.absoluteString)")
        player = AVPlayer(url: url)
        player.audiovisualBackgroundPlaybackPolicy = .automatic

        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                let seconds = time.seconds
                self.currentSeconds = seconds.isFinite ? seconds : 0
            }
        }

        installPlaybackPipelineObservers()
        CaptionTheaterPlaybackLogger.playbackFlow("Calling initial player.play() after pipeline wiring")
        player.play()

        Task { await loadDuration(for: url) }
        Task { await loadPresentationAspect(for: url) }
        Task { await preferEnglishLegibleMediaSelectionWhenReady() }
        applyScenarioSync(scenarioKind)
    }

    /// Registers player/item observers for Console-visible diagnostics and explicit playback starts.
    private func installPlaybackPipelineObservers() {
        keyPathObservations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] playerItem, _ in
            guard let self else { return }
            Task { @MainActor in
                CaptionTheaterPlaybackLogger.playbackFlow(
                    "AVPlayer.timeControlStatus=\(self.describeTimeControlStatus(playerItem.timeControlStatus)) reasonForWaiting=\(String(describing: playerItem.reasonForWaitingToPlay))"
                )
            }
        })

        keyPathObservations.append(player.observe(\.reasonForWaitingToPlay, options: [.new]) { [weak self] playerItem, _ in
            guard let self else { return }
            Task { @MainActor in
                CaptionTheaterPlaybackLogger.playbackDebug(
                    "AVPlayer.reasonForWaitingToPlay=\(String(describing: playerItem.reasonForWaitingToPlay))"
                )
            }
        })

        keyPathObservations.append(player.observe(\.currentItem, options: [.new]) { [weak self] playerItem, _ in
            guard let self else { return }
            Task { @MainActor in
                CaptionTheaterPlaybackLogger.playbackFlow("AVPlayer.currentItem changed; attaching status observer")
                self.observeCurrentItemStatus(playerItem.currentItem)
            }
        })

        observeCurrentItemStatus(player.currentItem)
    }

    private func describeTimeControlStatus(_ status: AVPlayer.TimeControlStatus) -> String {
        switch status {
        case .paused:
            return "paused"
        case .playing:
            return "playing"
        case .waitingToPlayAtSpecifiedRate:
            return "waitingToPlayAtSpecifiedRate"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    /// Observes ``AVPlayerItem/status`` for the active item and starts playback when ready.
    private func observeCurrentItemStatus(_ item: AVPlayerItem?) {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        guard let item else {
            CaptionTheaterPlaybackLogger.playbackFlow("observeCurrentItemStatus: nil item (nothing to observe)")
            return
        }

        CaptionTheaterPlaybackLogger.playbackFlow("Observing AVPlayerItem asset=\(item.asset)")

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            guard let self else { return }
            Task { @MainActor in
                switch observedItem.status {
                case .unknown:
                    CaptionTheaterPlaybackLogger.playbackDebug("AVPlayerItem.status=unknown")
                case .readyToPlay:
                    let seconds = observedItem.duration.seconds
                    CaptionTheaterPlaybackLogger.playbackFlow(
                        "AVPlayerItem.status=readyToPlay durationSec=\(seconds.isFinite ? seconds : -1) playbackLikelyToKeepUp=\(observedItem.isPlaybackLikelyToKeepUp)"
                    )
                    CaptionTheaterPlaybackLogger.playbackFlow("Issuing player.play() from readyToPlay observer")
                    self.player.play()
                case .failed:
                    let desc = observedItem.error?.localizedDescription ?? "nil"
                    CaptionTheaterPlaybackLogger.playbackFailure("AVPlayerItem.status=failed error=\(desc)")
                    self.playbackFailureDescription = observedItem.error?.localizedDescription ?? "Playback failed"
                @unknown default:
                    CaptionTheaterPlaybackLogger.playbackDebug("AVPlayerItem.status=unknownFutureCase")
                }
            }
        }
    }

    /// Polls until ``AVPlayer/currentItem`` exists, then selects English legible media when offered (demo helper).
    ///
    /// **Concurrency:** Runs as unstructured `Task` from the initializer on the main actor; uses short sleeps between polls and never blocks the UI thread for asset loads beyond `async` hops.
    private func preferEnglishLegibleMediaSelectionWhenReady() async {
        for attempt in 0 ..< 80 {
            if let item = player.currentItem {
                CaptionTheaterPlaybackLogger.playbackFlow("Legible selection: found currentItem after poll attempt=\(attempt)")
                await applyPreferredEnglishLegibleMediaSelectionIfPossible(to: item)
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        CaptionTheaterPlaybackLogger.playbackFailure("Legible selection: timed out waiting for currentItem")
    }

    /// Best-effort English subtitle selection for public demo streams (Mux *Tears of Steel*, etc.).
    private func applyPreferredEnglishLegibleMediaSelectionIfPossible(to item: AVPlayerItem) async {
        do {
            let asset = item.asset
            guard let group = try await asset.loadMediaSelectionGroup(for: .legible) else {
                CaptionTheaterPlaybackLogger.playbackFlow("Legible selection: no legible AVMediaSelectionGroup on asset")
                return
            }

            let preferred =
                group.options.first(where: { ($0.extendedLanguageTag ?? "").hasPrefix("en") })
                    ?? group.options.first(where: { $0.displayName.localizedCaseInsensitiveContains("english") })
                    ?? group.defaultOption
                    ?? group.options.first

            guard let preferred else {
                CaptionTheaterPlaybackLogger.playbackFlow("Legible selection: empty option list")
                return
            }

            item.select(preferred, in: group)
            CaptionTheaterPlaybackLogger.playbackFlow(
                "Legible selection: selected option displayName=\(preferred.displayName) tag=\(preferred.extendedLanguageTag ?? "nil")"
            )
        } catch {
            CaptionTheaterPlaybackLogger.playbackFailure("Legible selection: loadMediaSelectionGroup failed error=\(error.localizedDescription)")
        }
    }

    /// Computes layout rects for the video stage; returns `nil` until presentation aspect loads or inputs are invalid.
    func layoutGeometry(containerSize: CGSize) -> CaptionTheaterLayoutGeometry? {
        guard let aspect = pictureAspectRatioWidthOverHeight else {
            return nil
        }

        let inputs = CaptionTheaterLayoutInputs(
            containerSize: containerSize,
            pictureAspectRatioWidthOverHeight: aspect
        )

        let mode: CaptionTheaterLayoutPresentationMode =
            captionTheaterOptInAccepted && captionTheaterTopPinnedLayoutEnabled
                ? .captionTheaterAspectFitTopPinned
                : .nativeAspectFitCentered

        return CaptionTheaterLayoutEngine().geometry(for: inputs, mode: mode)
    }

    /// Loads bundled fixtures for `kind`, clearing packs when entering manual legacy mode.
    func applyScenario(_ kind: CaptionTheaterPlaybackScenarioKind) async {
        applyScenarioSync(kind)
    }

    private func applyScenarioSync(_ kind: CaptionTheaterPlaybackScenarioKind) {
        scenarioKind = kind
        scenarioLoadError = nil

        guard kind != .manualLegacyToggles else {
            scenarioPack = nil
            return
        }

        do {
            scenarioPack = try kind.loadPack(bundle: Bundle.main)
        } catch {
            scenarioPack = nil
            scenarioLoadError = String(describing: error)
        }
    }

    /// Removes periodic observers; safe to call multiple times.
    func detachPlaybackObservers() {
        CaptionTheaterPlaybackLogger.playbackFlow("detachPlaybackObservers: removing time observer and KVO tokens")
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

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            CaptionTheaterPlaybackLogger.playbackFlow("togglePlayPause -> pause")
            player.pause()
        } else {
            CaptionTheaterPlaybackLogger.playbackFlow("togglePlayPause -> play")
            player.play()
        }
    }

    func seek(by deltaSeconds: Double) {
        let base = player.currentTime()
        let target = CMTimeAdd(base, CMTime(seconds: deltaSeconds, preferredTimescale: base.timescale))
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seekToNormalizedProgress(_ progress: Double) {
        guard durationSeconds > 0 else { return }
        let clamped = max(0, min(1, progress))
        let target = CMTime(seconds: clamped * durationSeconds, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func eligibilityInspection() -> CaptionTheaterDebugDecisionInspection {
        let snapshot: CaptionTheaterEligibilitySnapshot
        let title: String
        let summary: String

        switch scenarioKind {
        case .manualLegacyToggles:
            snapshot = CaptionTheaterPlaybackShellSnapshotBuilder.snapshot(
                captionTheaterOptInAccepted: captionTheaterOptInAccepted,
                demoAssumeWebVTTSelected: demoAssumeWebVTTSelected,
                demoAssumeSafeLetterboxViewport: demoAssumeSafeLetterboxViewport
            )
            title = "Playback shell (manual toggles)"
            summary = CaptionTheaterPlaybackScenarioKind.manualLegacyToggles.summary

        default:
            title = scenarioKind.title
            summary =
                scenarioKind.summary
                + (scenarioLoadError.map { " (\($0))" } ?? "")

            if let scenarioPack {
                snapshot = CaptionTheaterPlaybackEvidenceAssembler().assemble(
                    isEnabledByUser: captionTheaterOptInAccepted,
                    adPlaybackState: .content,
                    manifest: scenarioPack.manifest,
                    provider: scenarioPack.provider,
                    subtitle: scenarioPack.subtitle
                )
            } else {
                snapshot = CaptionTheaterPlaybackEvidenceAssembler().assemble(
                    isEnabledByUser: captionTheaterOptInAccepted,
                    adPlaybackState: .content,
                    manifest: nil,
                    provider: nil,
                    subtitle: nil
                )
            }
        }

        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        return CaptionTheaterDebugDecisionInspection(
            scenarioTitle: title,
            scenarioSummary: summary,
            snapshot: snapshot,
            decision: decision
        )
    }

    private func loadDuration(for url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            durationSeconds = seconds.isFinite && seconds > 0 ? seconds : 0
            CaptionTheaterPlaybackLogger.playbackFlow("Loaded asset durationSec=\(durationSeconds)")
        } catch {
            durationSeconds = 0
            CaptionTheaterPlaybackLogger.playbackFailure("loadDuration failed error=\(error.localizedDescription)")
        }
    }

    /// Loads display aspect ratio from the first video track (natural size × preferred transform).
    ///
    /// **Concurrency:** Runs asynchronously off the hot path; updates main-actor state when complete.
    private func loadPresentationAspect(for url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                pictureAspectRatioWidthOverHeight = nil
                CaptionTheaterPlaybackLogger.playbackFailure("loadPresentationAspect: no video tracks on asset")
                return
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let displaySize = naturalSize.applying(transform)
            let width = abs(Double(displaySize.width))
            let height = abs(Double(displaySize.height))
            guard height > 0 else {
                pictureAspectRatioWidthOverHeight = nil
                CaptionTheaterPlaybackLogger.playbackFailure("loadPresentationAspect: zero display height after transform")
                return
            }

            pictureAspectRatioWidthOverHeight = width / height
            CaptionTheaterPlaybackLogger.playbackFlow(
                "Presentation aspect loaded naturalW=\(naturalSize.width) naturalH=\(naturalSize.height) displayAR=\(width / height) ultraWide=\(isUltraWideEncodedPicture)"
            )
        } catch {
            pictureAspectRatioWidthOverHeight = nil
            CaptionTheaterPlaybackLogger.playbackFailure("loadPresentationAspect failed error=\(error.localizedDescription)")
        }
    }
}
