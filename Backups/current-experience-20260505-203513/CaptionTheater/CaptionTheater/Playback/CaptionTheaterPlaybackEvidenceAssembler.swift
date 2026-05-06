//
//  CaptionTheaterPlaybackEvidenceAssembler.swift
//  CaptionTheater
//
//  Fuses manifest, provider, and subtitle inspectors into one eligibility snapshot (CT-0502).
//

import Foundation

/// Combines synchronous inspector outputs into a single ``CaptionTheaterEligibilitySnapshot``.
///
/// **Precedence:** subtitle classification drives ``CaptionTheaterSubtitleState`` when present.
/// Provider inspection wins for ``CaptionTheaterProtectedContentState`` when supplied; otherwise manifest
/// encryption hints fail closed. ``CaptionTheaterViewportState`` prefers explicit provider classification,
/// then conservative manifest resolution hints (until CT-0301 replaces hints).
nonisolated struct CaptionTheaterPlaybackEvidenceAssembler: Sendable {

    init() {}

    /// Builds the eligibility snapshot for the playback shell or future coordinators.
    ///
    /// - Parameters:
    ///   - isEnabledByUser: Product toggle after prompts (`Caption Theater session`).
    ///   - adPlaybackState: Linear/pause-promo awareness (stubbed to `.content` until ad coordinators land).
    ///   - manifest: Parsed HLS facts when a sanitized manifest accompanies playback.
    ///   - provider: Provider QC/catalog inspection when JSON is available.
    ///   - subtitle: ``SubtitleMetadataClassifier`` output when subtitle fixture metadata is available.
    func assemble(
        isEnabledByUser: Bool,
        adPlaybackState: CaptionTheaterAdPlaybackState,
        manifest: HLSManifestInspection?,
        provider: ProviderMetadataInspection?,
        subtitle: SubtitleMetadataClassification?
    ) -> CaptionTheaterEligibilitySnapshot {
        let subtitleState: CaptionTheaterSubtitleState
        var evidence: [CaptionTheaterEvidence]

        if let subtitle {
            subtitleState = subtitle.subtitleState
            evidence = subtitle.evidence
        } else {
            subtitleState = .noneSelected
            evidence = [
                .uncertain(
                    .subtitleCueMetadata,
                    "Subtitle metadata document was not loaded for this playback scenario."
                ),
            ]
        }

        let protectedContentState: CaptionTheaterProtectedContentState
        if let provider {
            protectedContentState = provider.protectedContentState
            evidence.append(contentsOf: provider.evidence)
        } else if manifest?.hasEncryptionSignal == true {
            protectedContentState = .protectedWithoutTrustedMetadata
            evidence.append(
                .uncertain(
                    .drmPolicy,
                    "Manifest declares encryption markers without accompanying trusted provider metadata."
                )
            )
        } else {
            protectedContentState = .clearContent
        }

        let viewportState = resolvedViewportState(manifest: manifest, provider: provider)
        evidence.append(contentsOf: manifestEvidence(manifest))

        return CaptionTheaterEligibilitySnapshot(
            isEnabledByUser: isEnabledByUser,
            adPlaybackState: adPlaybackState,
            subtitleState: subtitleState,
            viewportState: viewportState,
            protectedContentState: protectedContentState,
            evidence: evidence
        )
    }

    private func resolvedViewportState(
        manifest: HLSManifestInspection?,
        provider: ProviderMetadataInspection?
    ) -> CaptionTheaterViewportState {
        if let provider, provider.viewportState != .unknown {
            return provider.viewportState
        }
        return manifest.flatMap(Self.manifestViewportHint) ?? .unknown
    }

    private func manifestEvidence(_ manifest: HLSManifestInspection?) -> [CaptionTheaterEvidence] {
        guard let manifest else {
            return []
        }

        var rows: [CaptionTheaterEvidence] = []

        let transports = manifest.declaredSubtitleTransports
        if transports.isEmpty {
            rows.append(
                .positive(
                    .hlsManifest,
                    "Parsed manifest tags do not declare standalone subtitle renditions."
                )
            )
        } else {
            let summary = transports.map { String(describing: $0) }.sorted().joined(separator: ", ")
            rows.append(
                .positive(.hlsManifest, "Manifest declares subtitle transports: \(summary).")
            )
        }

        if manifest.hasEncryptionSignal {
            rows.append(
                .uncertain(
                    .hlsManifest,
                    "Manifest lists encryption-related tags; protected-content posture follows provider metadata when present."
                )
            )
        }

        if manifest.hasDiscontinuity {
            rows.append(
                .uncertain(
                    .hlsManifest,
                    "Manifest contains a discontinuity marker; ad boundaries belong to playback coordinators."
                )
            )
        }

        return rows
    }

    /// Uses the largest declared variant resolution as a **cheap hint**: 1920×1080 variants suggest a full-frame
    /// presentation relative to typical cinematic scopes. This is evidence scaffolding only—not pixel proof.
    static func manifestViewportHint(_ manifest: HLSManifestInspection) -> CaptionTheaterViewportState? {
        let resolutions = manifest.variants.compactMap(\.resolution)
        guard !resolutions.isEmpty else {
            return nil
        }

        let largest = resolutions.max {
            ($0.width * $0.height) < ($1.width * $1.height)
        }

        guard let largest else {
            return nil
        }

        if largest.width == 1920 && largest.height == 1080 {
            return .fullFrame
        }

        return nil
    }
}
