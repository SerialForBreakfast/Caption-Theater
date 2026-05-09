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

extension URL {

    /// Whether playback targets a remote HTTP(S) resource (typical HLS master playlist).
    ///
    /// Local file and bundle URLs return `false`; used only for Caption Theater **prompt heuristics**, not security.
    fileprivate var isRemoteHTTPPlaybackURL: Bool {
        guard let scheme = scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || scheme == "http"
    }
}

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

    /// True when the opened URL is HTTP(S), i.e. not a local file URL from the bundle.
    ///
    /// Remote manifests often declare cinematic variants while the **initial** video track still reports a 16∶9
    /// pixel raster (letterboxed scope inside the frame). The playback shell uses this flag to still offer Caption Theater.
    let playbackUsesRemoteURL: Bool

    private var timeObserverToken: Any?

    /// Key-path observations for player/item lifecycle logging.
    private var keyPathObservations: [NSKeyValueObservation] = []

    /// Observation for the active item’s ``AVPlayerItem/status`` (replaced when ``AVPlayer/currentItem`` changes).
    private var itemStatusObservation: NSKeyValueObservation?

    /// Coalesces repetitive ``layoutGeometry(container:contentInsets:)`` diagnostic logs across SwiftUI layout passes.
    private var lastLayoutGeometryDiagnosticToken: String?

    /// Logs once when Caption Theater layout uses cinematic fallback because pixels are still unknown.
    private var didLogNilReportedAspectFallback = false

    /// Last widened reported aspect logged (avoids spamming ``layoutAspectRatioWidthOverHeight()`` every layout tick).
    private var lastLoggedRemoteWidenReportedAspect: Double?

    /// Parsed duration in seconds; zero until loading finishes or if unknown.
    private(set) var durationSeconds: Double = 0

    /// Current playhead in seconds (updates periodically while presented).
    private(set) var currentSeconds: Double = 0

    /// Scrolling subtitle rows (**newest-first**): each distinct legible payload prepends a row; older rows move down.
    ///
    /// **Concurrency:** Updated from ``AVPlayerItemLegibleOutput`` on the main queue. Empty deliveries do not trim history;
    /// ``outputSequenceWasFlushed`` clears the list (seek / discontinuity).
    private(set) var captionScrollingCueEntries: [CaptionTheaterScrollingCueEntry] = []

    /// Most recently accepted newest-row plain text (mirror of ``captionScrollingCueEntries/first``).
    ///
    /// Useful for lightweight logging; primary UI binds to ``captionScrollingCueEntries``.
    private(set) var captionBandDisplayText: String = ""

    /// Push delegate host for ``AVPlayerItemLegibleOutput`` (must outlive the output).
    private let legibleCaptionSink = CaptionTheaterLegibleCaptionSink()

    /// Active legible output wired to ``player/currentItem`` while Caption Theater stacking is enabled.
    private var captionLegibleOutput: AVPlayerItemLegibleOutput?

    /// Player item that currently owns ``captionLegibleOutput`` (used for teardown).
    private weak var legibleOutputHostItem: AVPlayerItem?

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

    /// Increments whenever presentation-aspect probing completes so SwiftUI can present prompts reliably (`@Observable` / `onChange` timing).
    private(set) var presentationAspectGeneration: Int = 0

    /// `true` after ``loadPresentationAspect(for:)`` finishes (success or failure).
    private(set) var presentationProbeFinished: Bool = false

    /// `true` once encoded picture aspect exceeds ``CaptionTheaterPlaybackUILayout/ultrawideAspectRatioThresholdWidthOverHeight``.
    var isUltraWideEncodedPicture: Bool {
        guard let ar = pictureAspectRatioWidthOverHeight else {
            return false
        }
        return ar > Double(CaptionTheaterPlaybackUILayout.ultrawideAspectRatioThresholdWidthOverHeight)
    }

    /// Whether the shell should offer Caption Theater (ultra-wide pixels **or** remote stream heuristic).
    var qualifiesForCaptionTheaterOffer: Bool {
        isUltraWideEncodedPicture || playbackUsesRemoteURL
    }

    /// Human-readable picture aspect for debug HUD (nil while loading).
    var presentationAspectSummary: String {
        guard let ar = pictureAspectRatioWidthOverHeight else {
            return "Picture aspect: loading…"
        }
        return String(format: "Picture aspect (w÷h): %.3f", ar)
    }

    init(url: URL) {
        playbackUsesRemoteURL = url.isRemoteHTTPPlaybackURL
        CaptionTheaterPlaybackLogger.playbackFlow(
            "CaptionTheaterPlaybackShellViewModel init url=\(url.absoluteString) remote=\(playbackUsesRemoteURL)"
        )
        player = AVPlayer(url: url)
        player.audiovisualBackgroundPlaybackPolicy = .automatic
        /// Required so tvOS can auto-enable legible media when user prefs ask for captions; explicit ``AVPlayerItem/select(_:in:)`` still overrides stale Off states after Caption Theater attaches.
        player.appliesMediaSelectionCriteriaAutomatically = true

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
        CaptionTheaterPlaybackLogger.playbackFlow(
            "Legible captions use AVPlayerLayer + AVPlayerItemLegibleOutput (suppressesPlayerRendering=true) into the Caption Theater band."
        )
        wireLegibleCaptionSinkHandlers()
        applyScenarioSync(scenarioKind)
    }

    /// Attaches ``AVPlayerItemLegibleOutput``, selects a default legible media option, and starts vending cues into ``captionScrollingCueEntries``.
    ///
    /// **Concurrency:** Main-actor entry point; awaits asset media-selection loads without blocking observers.
    func refreshCaptionTheaterLegiblePipeline(reason: String) {
        Task { @MainActor in
            await attachCaptionTheaterLegibleOutputIfNeeded(reason: reason)
        }
    }

    private func wireLegibleCaptionSinkHandlers() {
        legibleCaptionSink.onAttributedStrings = { [weak self] strings, itemTime in
            Task { @MainActor in
                self?.applyLegibleAttributedStrings(strings, itemTime: itemTime)
            }
        }
        legibleCaptionSink.onOutputSequenceFlushed = { [weak self] in
            Task { @MainActor in
                self?.handleLegibleOutputSequenceFlush()
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
        captionBandDisplayText = captionScrollingCueEntries.first?.text ?? ""
    }

    private func handleLegibleOutputSequenceFlush() {
        captionScrollingCueEntries = []
        captionBandDisplayText = ""
    }

    private func detachCaptionTheaterLegibleOutput(reason: String) {
        guard let output = captionLegibleOutput else {
            return
        }
        if let host = legibleOutputHostItem {
            host.remove(output)
            CaptionTheaterPlaybackLogger.playbackFlow("Caption Theater legible detached reason=\(reason)")
        }
        captionLegibleOutput = nil
        legibleOutputHostItem = nil
        legibleCaptionSink.resetLegibleDeliveryTelemetry()
    }

    private func attachCaptionTheaterLegibleOutputIfNeeded(reason: String) async {
        guard captionTheaterOptInAccepted, captionTheaterTopPinnedLayoutEnabled else {
            detachCaptionTheaterLegibleOutput(reason: "\(reason) caption theater layout off")
            captionScrollingCueEntries = []
            captionBandDisplayText = ""
            return
        }

        guard let item = player.currentItem else {
            CaptionTheaterPlaybackLogger.playbackFlow("Caption Theater legible: defer \(reason) — nil currentItem")
            return
        }

        guard item.status == .readyToPlay else {
            CaptionTheaterPlaybackLogger.playbackFlow(
                "Caption Theater legible: defer \(reason) — item not readyToPlay status=\(String(describing: item.status))"
            )
            return
        }

        if captionLegibleOutput != nil, legibleOutputHostItem === item {
            do {
                try await selectCaptionTheaterLegibleMediaOption(for: item)
            } catch {
                CaptionTheaterPlaybackLogger.playbackFailure(
                    "Caption Theater legible: media selection refresh failed (\(reason)) error=\(error.localizedDescription)"
                )
            }
            return
        }

        detachCaptionTheaterLegibleOutput(reason: "reattach before \(reason)")
        legibleCaptionSink.resetLegibleDeliveryTelemetry()

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
            CaptionTheaterPlaybackLogger.playbackFailure(
                "Caption Theater legible: media selection failed (\(reason)) error=\(error.localizedDescription)"
            )
            return
        }

        CaptionTheaterPlaybackLogger.playbackFlow("Caption Theater legible output attached (\(reason))")
    }

    private func selectCaptionTheaterLegibleMediaOption(for item: AVPlayerItem) async throws {
        let asset = item.asset
        guard let group = try await asset.loadMediaSelectionGroup(for: .legible) else {
            CaptionTheaterPlaybackLogger.playbackFlow("Caption Theater legible: asset has no legible media selection group")
            return
        }

        let priorName = item.currentMediaSelection.selectedMediaOption(in: group)?.displayName ?? "nil"

        guard let option = group.defaultOption ?? group.options.first else {
            CaptionTheaterPlaybackLogger.playbackFlow("Caption Theater legible: legible group has zero options")
            return
        }

        item.select(option, in: group)
        CaptionTheaterPlaybackLogger.playbackFlow(
            "Caption Theater legible: selected option=\(option.displayName) prior=\(priorName) optionCount=\(group.options.count)"
        )
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

        keyPathObservations.append(player.observe(\.reasonForWaitingToPlay, options: [.new]) { playerItem, _ in
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
                self.detachCaptionTheaterLegibleOutput(reason: "AVPlayer.currentItem changed")
                self.observeCurrentItemStatus(playerItem.currentItem)
                self.refreshCaptionTheaterLegiblePipeline(reason: "AVPlayer.currentItem changed")
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
                    Task { await self.reloadPresentationAspectFromCurrentItemAsset(reason: "readyToPlay") }
                    self.refreshCaptionTheaterLegiblePipeline(reason: "readyToPlay")
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

    /// Aspect ratio fed into ``CaptionTheaterLayoutEngine`` (may widen remote 16∶9 rasters after Caption Theater opt-in).
    ///
    /// When **reported** pixels are still unknown (common right after opening an HLS master URL), remote Caption Theater sessions use the cinematic fallback so stacked layout can render immediately after opt-in.
    func layoutAspectRatioWidthOverHeight() -> Double? {
        let threshold = Double(CaptionTheaterPlaybackUILayout.ultrawideAspectRatioThresholdWidthOverHeight)
        let fallback = Double(CaptionTheaterPlaybackUILayout.remoteScopeFallbackAspectRatioWidthOverHeight)

        guard let reported = pictureAspectRatioWidthOverHeight else {
            guard playbackUsesRemoteURL,
                  captionTheaterOptInAccepted,
                  captionTheaterTopPinnedLayoutEnabled
            else {
                return nil
            }
            if !didLogNilReportedAspectFallback {
                didLogNilReportedAspectFallback = true
                CaptionTheaterPlaybackLogger.playbackFlow(
                    "layoutAspectRatio: reported AR still nil (typical before HLS variant binds); remote Caption Theater using fallback=\(fallback)"
                )
            }
            return fallback
        }

        guard playbackUsesRemoteURL,
              captionTheaterOptInAccepted,
              captionTheaterTopPinnedLayoutEnabled,
              reported <= threshold
        else {
            return reported
        }

        if lastLoggedRemoteWidenReportedAspect != reported {
            lastLoggedRemoteWidenReportedAspect = reported
            CaptionTheaterPlaybackLogger.playbackFlow(
                "layoutAspectRatio: remote cinematic widen reported=\(reported) using=\(fallback)"
            )
        }
        return fallback
    }

    /// One-line diagnostics after alert choices or probe retries (container-independent).
    func logCaptionTheaterLayoutPipeline(reason: String) {
        let layoutAR = layoutAspectRatioWidthOverHeight().map { String(format: "%.4f", $0) } ?? "nil"
        let reported = pictureAspectRatioWidthOverHeight.map { String(format: "%.4f", $0) } ?? "nil"
        CaptionTheaterPlaybackLogger.playbackFlow(
            "\(reason) remote=\(playbackUsesRemoteURL) optIn=\(captionTheaterOptInAccepted) topPin=\(captionTheaterTopPinnedLayoutEnabled) reportedAR=\(reported) layoutAR=\(layoutAR)"
        )
    }

    /// Computes layout rects for the video stage; returns `nil` until presentation aspect loads or inputs are invalid.
    ///
    /// Pass ``CaptionTheaterLayoutContentInsets`` from the host—typically ``GeometryProxy/safeAreaInsets`` on tvOS—so
    /// aspect-fit math and the caption band stay inside the interactive safe region (CT-0303).
    func layoutGeometry(
        containerSize: CGSize,
        contentInsets: CaptionTheaterLayoutContentInsets = .zero
    ) -> CaptionTheaterLayoutGeometry? {
        let mode: CaptionTheaterLayoutPresentationMode =
            captionTheaterOptInAccepted && captionTheaterTopPinnedLayoutEnabled
                ? .captionTheaterAspectFitTopPinned
                : .nativeAspectFitCentered

        guard let aspect = layoutAspectRatioWidthOverHeight() else {
            logLayoutGeometryBlocked(
                containerSize: containerSize,
                mode: mode,
                detail: "layoutAspectRatioWidthOverHeight returned nil"
            )
            return nil
        }

        let inputs = CaptionTheaterLayoutInputs(
            containerSize: containerSize,
            pictureAspectRatioWidthOverHeight: aspect,
            contentInsets: contentInsets
        )

        guard let geometry = CaptionTheaterLayoutEngine().geometry(for: inputs, mode: mode) else {
            logLayoutGeometryBlocked(
                containerSize: containerSize,
                mode: mode,
                detail: "CaptionTheaterLayoutEngine returned nil (invalid inputs)"
            )
            return nil
        }

        logLayoutGeometryComputed(containerSize: containerSize, mode: mode, aspect: aspect, geometry: geometry)
        return geometry
    }

    private func logLayoutGeometryBlocked(containerSize: CGSize, mode: CaptionTheaterLayoutPresentationMode, detail: String) {
        let reported = pictureAspectRatioWidthOverHeight.map { String(format: "%.4f", $0) } ?? "nil"
        let layoutAR = layoutAspectRatioWidthOverHeight().map { String(format: "%.4f", $0) } ?? "nil"
        let token =
            "blocked|\(detail)|\(mode)|\(Int(containerSize.width))x\(Int(containerSize.height))|\(reported)|\(layoutAR)|\(captionTheaterOptInAccepted)|\(captionTheaterTopPinnedLayoutEnabled)"
        guard token != lastLayoutGeometryDiagnosticToken else {
            return
        }
        lastLayoutGeometryDiagnosticToken = token
        CaptionTheaterPlaybackLogger.playbackFlow(
            "layoutGeometry BLOCKED: \(detail) container=\(Int(containerSize.width))x\(Int(containerSize.height)) mode=\(mode) reportedAR=\(reported) layoutAR=\(layoutAR) ctOptIn=\(captionTheaterOptInAccepted) topPin=\(captionTheaterTopPinnedLayoutEnabled)"
        )
    }

    private func logLayoutGeometryComputed(
        containerSize: CGSize,
        mode: CaptionTheaterLayoutPresentationMode,
        aspect: Double,
        geometry: CaptionTheaterLayoutGeometry
    ) {
        let pic = geometry.activePictureRect
        let cap = geometry.captionReadingRect
        let token =
            "ok|\(mode)|\(Int(containerSize.width))x\(Int(containerSize.height))|\(String(format: "%.4f", aspect))|\(Int(pic.width))x\(Int(pic.height))|\(Int(cap.height))"
        guard token != lastLayoutGeometryDiagnosticToken else {
            return
        }
        lastLayoutGeometryDiagnosticToken = token
        CaptionTheaterPlaybackLogger.playbackFlow(
            "layoutGeometry OK: mode=\(mode) container=\(Int(containerSize.width))x\(Int(containerSize.height)) aspect=\(String(format: "%.4f", aspect)) pictureRect=\(Int(pic.width))x\(Int(pic.height)) origin=\(Int(pic.origin.x)),\(Int(pic.origin.y)) captionBandH=\(Int(cap.height))"
        )
    }

    /// Reloads natural/display dimensions from the **player-bound** asset after the HLS stack attaches variant tracks.
    ///
    /// **Concurrency:** Called from the main actor via unstructured `Task` when ``AVPlayerItem/status`` becomes ``readyToPlay``; performs async asset/track loads off the synchronous KVO callback path.
    private func reloadPresentationAspectFromCurrentItemAsset(reason: String) async {
        guard let asset = player.currentItem?.asset else {
            CaptionTheaterPlaybackLogger.playbackFlow("reloadPresentationAspect(\(reason)): no player.currentItem.asset")
            return
        }

        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                CaptionTheaterPlaybackLogger.playbackFlow(
                    "reloadPresentationAspect(\(reason)): still zero video tracks (HLS may still be negotiating)"
                )
                return
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let displaySize = naturalSize.applying(transform)
            let width = abs(Double(displaySize.width))
            let height = abs(Double(displaySize.height))
            guard height > 0 else {
                CaptionTheaterPlaybackLogger.playbackFailure(
                    "reloadPresentationAspect(\(reason)): zero height after transform natural=\(naturalSize)"
                )
                return
            }

            let computed = width / height
            if pictureAspectRatioWidthOverHeight != computed {
                pictureAspectRatioWidthOverHeight = computed
                presentationAspectGeneration += 1
                didLogNilReportedAspectFallback = false
                CaptionTheaterPlaybackLogger.playbackFlow(
                    "reloadPresentationAspect(\(reason)): displayAR=\(computed) natural=\(naturalSize.width)x\(naturalSize.height) ultraWide=\(isUltraWideEncodedPicture) generation=\(presentationAspectGeneration)"
                )
            } else {
                CaptionTheaterPlaybackLogger.playbackDebug(
                    "reloadPresentationAspect(\(reason)): unchanged AR=\(computed)"
                )
            }
        } catch {
            CaptionTheaterPlaybackLogger.playbackFailure(
                "reloadPresentationAspect(\(reason)) failed error=\(error.localizedDescription)"
            )
        }
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
        detachCaptionTheaterLegibleOutput(reason: "detachPlaybackObservers")
        captionScrollingCueEntries = []
        captionBandDisplayText = ""

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
        defer {
            presentationProbeFinished = true
            presentationAspectGeneration += 1
            CaptionTheaterPlaybackLogger.playbackFlow(
                "Presentation probe finished generation=\(presentationAspectGeneration) remote=\(playbackUsesRemoteURL) ar=\(pictureAspectRatioWidthOverHeight.map { String(format: "%.4f", $0) } ?? "nil") offerEligible=\(qualifiesForCaptionTheaterOffer)"
            )
        }

        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                pictureAspectRatioWidthOverHeight = nil
                CaptionTheaterPlaybackLogger.playbackFlow(
                    "loadPresentationAspect: zero video tracks on master AVURLAsset yet (normal for HLS until AVPlayer binds a variant); will retry from currentItem.asset at readyToPlay"
                )
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
