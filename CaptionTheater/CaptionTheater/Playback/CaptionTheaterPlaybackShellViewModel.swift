//
//  CaptionTheaterPlaybackShellViewModel.swift
//  CaptionTheater
//
//  Owns AVPlayer observation for the tvOS playback shell sample (CT-0501).
//

import AVFoundation
import Foundation
import Observation

/// Playback shell state bridge between `AVPlayer` timers and SwiftUI on the main actor.
///
/// **Concurrency:** All methods and properties are main-actor isolated; UI reads timers and issues
/// transport commands on the main actor. Call ``detachPlaybackObservers()`` from `onDisappear` so
/// periodic observers never outlive the hosting view.
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

    /// User accepted the Caption Theater prompt while enabling the feature toggle.
    var captionTheaterOptInAccepted: Bool = false

    /// Demo-only: force WebVTT subtitle state for eligibility recordings.
    var demoAssumeWebVTTSelected: Bool = false

    /// Demo-only: force safe letterbox viewport classification.
    var demoAssumeSafeLetterboxViewport: Bool = false

    /// Shows compact eligibility telemetry over the video layer.
    var showDebugOverlay: Bool = false

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
        let snapshot = CaptionTheaterPlaybackShellSnapshotBuilder.snapshot(
            captionTheaterOptInAccepted: captionTheaterOptInAccepted,
            demoAssumeWebVTTSelected: demoAssumeWebVTTSelected,
            demoAssumeSafeLetterboxViewport: demoAssumeSafeLetterboxViewport
        )
        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        return CaptionTheaterDebugDecisionInspection(
            scenarioTitle: "Playback shell",
            scenarioSummary:
                "Snapshot assembled from shell toggles; replace with stream-derived evidence in CT-0502.",
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
}
