//
//  CaptionTheaterPlaybackShellSnapshotBuilder.swift
//  CaptionTheater
//
//  Builds eligibility snapshots for the playback shell until CT-0502 wires manifest/subtitle adapters.
//

import Foundation

/// Constructs ``CaptionTheaterEligibilitySnapshot`` values for the tvOS playback shell.
///
/// Real playback should replace demo toggles with `AVPlayer`/manifest-driven evidence. Until then,
/// this builder stays explicit about what is measured versus what is assumed for stakeholder demos.
nonisolated enum CaptionTheaterPlaybackShellSnapshotBuilder {

    /// Creates a snapshot reflecting shell toggles and conservative defaults elsewhere.
    ///
    /// - Parameters:
    ///   - captionTheaterOptInAccepted: Maps to ``CaptionTheaterEligibilitySnapshot/isEnabledByUser``
    ///     after the product prompt accepts entering Caption Theater.
    ///   - demoAssumeWebVTTSelected: When `true`, treats subtitle state as WebVTT for demo recordings.
    ///   - demoAssumeSafeLetterboxViewport: When `true`, treats viewport analysis as safe letterbox.
    static func snapshot(
        captionTheaterOptInAccepted: Bool,
        demoAssumeWebVTTSelected: Bool,
        demoAssumeSafeLetterboxViewport: Bool
    ) -> CaptionTheaterEligibilitySnapshot {
        let subtitleState: CaptionTheaterSubtitleState =
            demoAssumeWebVTTSelected ? .webVTT : .noneSelected
        let viewportState: CaptionTheaterViewportState =
            demoAssumeSafeLetterboxViewport ? .safeCinematicLetterbox : .unknown

        var evidence: [CaptionTheaterEvidence] = [
            .uncertain(
                .avFoundationMetadata,
                "Playback shell: stream adapters not wired yet (CT-0502); ad/subtitle/viewport fields are partially stubbed."
            ),
        ]
        if demoAssumeWebVTTSelected {
            evidence.append(
                .positive(.subtitleCueMetadata, "Demo toggle: assuming WebVTT is selected.")
            )
        }
        if demoAssumeSafeLetterboxViewport {
            evidence.append(
                .positive(.viewportAnalysis, "Demo toggle: assuming safe cinematic letterbox viewport.")
            )
        }

        return CaptionTheaterEligibilitySnapshot(
            isEnabledByUser: captionTheaterOptInAccepted,
            adPlaybackState: .content,
            subtitleState: subtitleState,
            viewportState: viewportState,
            protectedContentState: .clearContent,
            evidence: evidence
        )
    }
}
