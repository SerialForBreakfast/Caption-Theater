import Foundation

/// Decodes and evaluates sanitized provider-side Caption Theater metadata.
///
/// `ProviderMetadataInspector` is stateless, synchronous, and nonisolated. Callers should provide
/// already-fetched local JSON data from a trusted fixture or provider adapter; this type does not perform
/// network requests, entitlement calls, key loading, media loading, or DRM interaction.
nonisolated struct ProviderMetadataInspector: Sendable {
    /// Creates an inspector with no retained state.
    init() {}

    /// Decodes provider metadata JSON into a typed document.
    func decode(_ data: Data) throws -> ProviderMetadataDocument {
        try JSONDecoder().decode(ProviderMetadataDocument.self, from: data)
    }

    /// Evaluates optional provider metadata into decision-engine inputs and explainable evidence.
    ///
    /// Missing metadata fails closed for protected content. Trusted positive metadata may authorize a
    /// protected-content path, while blocklist and native-only metadata produce native playback evidence.
    func inspect(_ document: ProviderMetadataDocument?) -> ProviderMetadataInspection {
        guard let metadata = document?.captionTheater else {
            return ProviderMetadataInspection(
                metadata: nil,
                protectedContentState: .protectedWithoutTrustedMetadata,
                viewportState: .unknown,
                evidence: [.uncertain(.drmPolicy, "Protected content is missing trusted provider metadata.")]
            )
        }

        var evidence = [
            CaptionTheaterEvidence(
                source: .providerSideQcMetadata,
                polarity: metadata.isTrusted ? .positive : .uncertain,
                message: "Provider metadata source \(metadata.source.rawValue) reported policy \(metadata.policy.rawValue)."
            )
        ]

        if metadata.warnings.contains(.burnedInSubtitleRisk) {
            evidence.append(.negative(.providerSideQcMetadata, "Provider metadata warns about burned-in subtitle risk."))
        }

        switch metadata.policy {
        case .eligible where metadata.canAuthorizeCaptionTheater:
            evidence.append(.positive(.providerSideQcMetadata, "Trusted metadata declares a safe active picture and caption region."))
            return ProviderMetadataInspection(
                metadata: metadata,
                protectedContentState: .trustedMetadataAllowed,
                viewportState: .safeCinematicLetterbox,
                evidence: evidence
            )
        case .blocklisted:
            evidence.append(.negative(.providerSideQcMetadata, "Provider metadata blocklists Caption Theater for this asset."))
            return ProviderMetadataInspection(
                metadata: metadata,
                protectedContentState: metadata.isTrusted ? .trustedMetadataAllowed : .protectedWithoutTrustedMetadata,
                viewportState: .unsafe,
                evidence: evidence
            )
        case .nativeOnly:
            evidence.append(.negative(.providerSideQcMetadata, "Provider metadata requires native presentation."))
            return ProviderMetadataInspection(
                metadata: metadata,
                protectedContentState: metadata.isTrusted ? .trustedMetadataAllowed : .protectedWithoutTrustedMetadata,
                viewportState: .unsafe,
                evidence: evidence
            )
        case .eligible:
            evidence.append(.uncertain(.providerSideQcMetadata, "Provider metadata is incomplete for protected-content eligibility."))
            return ProviderMetadataInspection(
                metadata: metadata,
                protectedContentState: .protectedWithoutTrustedMetadata,
                viewportState: .unknown,
                evidence: evidence
            )
        }
    }
}

/// Top-level provider metadata document used by local JSON fixtures.
nonisolated struct ProviderMetadataDocument: Codable, Equatable, Sendable {
    let captionTheater: ProviderCaptionTheaterMetadata
}

/// Caption Theater metadata supplied by a trusted provider-side QC or catalog pipeline.
nonisolated struct ProviderCaptionTheaterMetadata: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let policy: ProviderMetadataPolicy
    let source: ProviderMetadataSource
    let confidence: Double
    let supportsPersistence: Bool
    let declaredActiveAspectRatio: Double?
    let activePictureRect: ProviderMetadataRect?
    let safeCaptionRegions: [ProviderMetadataRect]
    let allowedLayouts: [ProviderMetadataLayout]
    let notes: [String]
    let warnings: [ProviderMetadataWarning]
    let segments: [ProviderMetadataTimelineSegment]

    /// Whether this metadata is trusted enough to authorize protected-content eligibility.
    var isTrusted: Bool {
        source == .providerQC && confidence >= 0.8
    }

    /// Whether the metadata contains the minimum positive evidence needed for Caption Theater.
    var canAuthorizeCaptionTheater: Bool {
        isTrusted
            && supportsPersistence
            && activePictureRect != nil
            && !safeCaptionRegions.isEmpty
            && allowedLayouts.contains(.expandedBottomRegion)
            && !warnings.contains(.burnedInSubtitleRisk)
    }

    /// Returns the provider segment active at a playback time, if one is declared.
    func segment(containing playbackTime: Double) -> ProviderMetadataTimelineSegment? {
        segments.first { segment in
            playbackTime >= segment.start && playbackTime < segment.end
        }
    }
}

/// Result of evaluating optional provider metadata for a protected-content decision.
nonisolated struct ProviderMetadataInspection: Equatable, Sendable {
    let metadata: ProviderCaptionTheaterMetadata?
    let protectedContentState: CaptionTheaterProtectedContentState
    let viewportState: CaptionTheaterViewportState
    let evidence: [CaptionTheaterEvidence]

    /// Creates a decision-engine snapshot using provider metadata as the protected-content authority.
    func eligibilitySnapshot(
        isEnabledByUser: Bool = true,
        adPlaybackState: CaptionTheaterAdPlaybackState = .content,
        subtitleState: CaptionTheaterSubtitleState = .webVTT
    ) -> CaptionTheaterEligibilitySnapshot {
        CaptionTheaterEligibilitySnapshot(
            isEnabledByUser: isEnabledByUser,
            adPlaybackState: adPlaybackState,
            subtitleState: subtitleState,
            viewportState: viewportState,
            protectedContentState: protectedContentState,
            evidence: evidence
        )
    }
}

/// Caption Theater policy declared by provider metadata.
nonisolated enum ProviderMetadataPolicy: String, Codable, Equatable, Sendable {
    case eligible
    case nativeOnly
    case blocklisted
}

/// Source that produced provider metadata.
nonisolated enum ProviderMetadataSource: String, Codable, Equatable, Sendable {
    case providerQC = "provider-qc"
    case catalog
    case fixture
}

/// Caption Theater layouts explicitly authorized by provider metadata.
nonisolated enum ProviderMetadataLayout: String, Codable, Equatable, Sendable {
    case expandedBottomRegion
}

/// Provider warnings that constrain Caption Theater eligibility.
nonisolated enum ProviderMetadataWarning: String, Codable, Equatable, Sendable {
    case burnedInSubtitleRisk
    case variableAspectRatio
    case legalTextRisk
}

/// A rectangle in encoded video coordinate space.
nonisolated struct ProviderMetadataRect: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

/// Timeline metadata that can force native presentation for specific playback ranges.
nonisolated struct ProviderMetadataTimelineSegment: Codable, Equatable, Sendable {
    let start: Double
    let end: Double
    let policy: ProviderMetadataPolicy
    let reason: String?
}
