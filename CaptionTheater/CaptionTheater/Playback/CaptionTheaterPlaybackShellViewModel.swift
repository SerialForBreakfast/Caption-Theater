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
/// Scenario fixtures load synchronously from ``Bundle/main`` on the main actor because files are tiny;
/// larger manifests belong in background tasks once parsing grows beyond microsecond budgets.
@MainActor
@Observable
final class CaptionTheaterPlaybackShellViewModel {

    /// Sample clip player for fixture playback.
    let player: AVPlayer

    private var timeObserverToken: Any?

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

    /// Shows compact eligibility telemetry over the video layer.
    var showDebugOverlay: Bool = false

    /// Picture aspect ratio (width ÷ height) from the primary video track (display dimensions); drives ``CaptionTheaterLayoutEngine``.
    private(set) var pictureAspectRatioWidthOverHeight: Double?

    /// When true, ``CaptionTheaterLayoutEngine`` uses ``CaptionTheaterLayoutPresentationMode/captionTheaterAspectFitTopPinned`` (MVP negative-space captions).
    var captionTheaterTopPinnedLayoutEnabled: Bool = false

    /// Human-readable picture aspect for debug HUD (nil while loading).
    var presentationAspectSummary: String {
        guard let ar = pictureAspectRatioWidthOverHeight else {
            return "Picture aspect: loading…"
        }
        return String(format: "Picture aspect (w÷h): %.3f", ar)
    }

    init(url: URL) {
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

        Task { await loadDuration(for: url) }
        Task { await loadPresentationAspect(for: url) }
        applyScenarioSync(scenarioKind)
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
            captionTheaterTopPinnedLayoutEnabled
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
        guard let token = timeObserverToken else { return }
        player.removeTimeObserver(token)
        timeObserverToken = nil
    }

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
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
        } catch {
            durationSeconds = 0
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
                return
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let displaySize = naturalSize.applying(transform)
            let width = abs(Double(displaySize.width))
            let height = abs(Double(displaySize.height))
            guard height > 0 else {
                pictureAspectRatioWidthOverHeight = nil
                return
            }

            pictureAspectRatioWidthOverHeight = width / height
        } catch {
            pictureAspectRatioWidthOverHeight = nil
        }
    }
}
