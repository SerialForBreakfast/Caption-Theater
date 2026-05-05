import Foundation

/// Evaluates whether Caption Theater may activate for a point-in-time playback snapshot.
///
/// `CaptionTheaterDecisionEngine` is intentionally stateless and does not perform asynchronous work.
/// Callers provide the current evidence snapshot, and the engine returns a deterministic decision that
/// can be tested without `AVPlayer`, SwiftUI, frame sampling, or platform UI. Coordination, cancellation,
/// and actor ownership belong in a future playback coordinator.
struct CaptionTheaterDecisionEngine: Sendable {
    /// Creates a decision engine with no retained state.
    init() {}

    /// Returns the safest Caption Theater decision for the supplied evidence snapshot.
    ///
    /// The engine fails closed: user disablement, ad/promo presentation, unsupported subtitle state,
    /// unsafe viewport evidence, DRM uncertainty, and incomplete evidence all produce native playback.
    func decision(for snapshot: CaptionTheaterEligibilitySnapshot) -> CaptionTheaterDecision {
        var evidence = snapshot.evidence

        if !snapshot.isEnabledByUser {
            return .ineligible(
                reason: .disabledByUser,
                evidence: evidence + [.negative(.userSetting, "Caption Theater is disabled by the user.")]
            )
        }

        switch snapshot.adPlaybackState {
        case .content:
            evidence.append(.positive(.adLifecycleEvent, "Playback is currently content, not an ad or promo."))
        case .linearAd:
            return .ineligible(
                reason: .adPlaybackActive,
                evidence: evidence + [.negative(.adLifecycleEvent, "Linear ad playback requires native presentation.")]
            )
        case .pausePromo:
            return .ineligible(
                reason: .promoPlaybackActive,
                evidence: evidence + [.negative(.adLifecycleEvent, "Pause promos are not eligible for Caption Theater presentation.")]
            )
        case .unknown:
            return .uncertain(
                reason: .unknownAdPlaybackState,
                evidence: evidence + [.uncertain(.adLifecycleEvent, "Unknown ad state must fail closed.")]
            )
        }

        switch snapshot.subtitleState {
        case .webVTT:
            evidence.append(.positive(.subtitleCueMetadata, "WebVTT is eligible for the first Caption Theater cue model."))
        case .noneSelected:
            return .ineligible(
                reason: .noSubtitleTrackSelected,
                evidence: evidence + [.negative(.subtitleCueMetadata, "No selected subtitle track is available to render.")]
            )
        case .unsupported:
            return .ineligible(
                reason: .unsupportedSubtitleFormat,
                evidence: evidence + [.negative(.subtitleCueMetadata, "The selected subtitle format is not eligible for persistence.")]
            )
        case .unknown:
            return .uncertain(
                reason: .unknownSubtitleFormat,
                evidence: evidence + [.uncertain(.subtitleCueMetadata, "The selected subtitle format is unknown.")]
            )
        }

        switch snapshot.viewportState {
        case .safeCinematicLetterbox:
            evidence.append(.positive(.viewportAnalysis, "Viewport analysis found safe cinematic letterbox space."))
        case .fullFrame:
            return .ineligible(
                reason: .noUsefulInactiveRegion,
                evidence: evidence + [.negative(.viewportAnalysis, "Full-frame video has no useful inactive caption region.")]
            )
        case .unsafe:
            return .ineligible(
                reason: .unsafeViewportRegion,
                evidence: evidence + [.negative(.viewportAnalysis, "Inactive-looking viewport regions contain unsafe visual evidence.")]
            )
        case .variableAspectRatio:
            return .ineligible(
                reason: .variableAspectRatio,
                evidence: evidence + [.negative(.viewportAnalysis, "Variable aspect ratio requires native playback for the MVP.")]
            )
        case .unknown:
            return .uncertain(
                reason: .unknownViewportSafety,
                evidence: evidence + [.uncertain(.viewportAnalysis, "Viewport safety is unknown.")]
            )
        }

        switch snapshot.protectedContentState {
        case .clearContent:
            evidence.append(.positive(.drmPolicy, "Clear content may use local viewport evidence."))
        case .trustedMetadataAllowed:
            evidence.append(.positive(.providerSideQcMetadata, "Trusted provider metadata allows protected-content eligibility."))
        case .protectedWithoutTrustedMetadata:
            return .uncertain(
                reason: .protectedContentRequiresTrustedMetadata,
                evidence: evidence + [.uncertain(.drmPolicy, "Protected content requires trusted metadata or allowlisting.")]
            )
        case .unknown:
            return .uncertain(
                reason: .unknownProtectedContentState,
                evidence: evidence + [.uncertain(.drmPolicy, "Protected-content state is unknown.")]
            )
        }

        return .eligible(evidence: evidence)
    }
}

/// A point-in-time input model for Caption Theater eligibility decisions.
///
/// Snapshots are value types so playback, ad, subtitle, metadata, and viewport adapters can construct
/// them on their own actor or thread and pass them into the stateless decision engine without sharing
/// mutable state.
struct CaptionTheaterEligibilitySnapshot: Equatable, Sendable {
    let isEnabledByUser: Bool
    let adPlaybackState: CaptionTheaterAdPlaybackState
    let subtitleState: CaptionTheaterSubtitleState
    let viewportState: CaptionTheaterViewportState
    let protectedContentState: CaptionTheaterProtectedContentState
    let evidence: [CaptionTheaterEvidence]

    /// Creates the evidence snapshot consumed by `CaptionTheaterDecisionEngine`.
    init(
        isEnabledByUser: Bool,
        adPlaybackState: CaptionTheaterAdPlaybackState,
        subtitleState: CaptionTheaterSubtitleState,
        viewportState: CaptionTheaterViewportState,
        protectedContentState: CaptionTheaterProtectedContentState,
        evidence: [CaptionTheaterEvidence] = []
    ) {
        self.isEnabledByUser = isEnabledByUser
        self.adPlaybackState = adPlaybackState
        self.subtitleState = subtitleState
        self.viewportState = viewportState
        self.protectedContentState = protectedContentState
        self.evidence = evidence
    }
}

/// The decision returned by the Caption Theater eligibility engine.
enum CaptionTheaterDecision: Equatable, Sendable {
    case eligible(evidence: [CaptionTheaterEvidence])
    case ineligible(reason: CaptionTheaterIneligibilityReason, evidence: [CaptionTheaterEvidence])
    case uncertain(reason: CaptionTheaterUncertaintyReason, evidence: [CaptionTheaterEvidence])
}

/// Reasons Caption Theater should stay in native playback even though the evidence is understood.
enum CaptionTheaterIneligibilityReason: Equatable, Sendable {
    case disabledByUser
    case adPlaybackActive
    case promoPlaybackActive
    case noSubtitleTrackSelected
    case unsupportedSubtitleFormat
    case noUsefulInactiveRegion
    case unsafeViewportRegion
    case variableAspectRatio
}

/// Reasons Caption Theater should fail closed because the evidence is incomplete or unknown.
enum CaptionTheaterUncertaintyReason: Equatable, Sendable {
    case unknownAdPlaybackState
    case unknownSubtitleFormat
    case unknownViewportSafety
    case protectedContentRequiresTrustedMetadata
    case unknownProtectedContentState
}

/// Current ad or promo state supplied by the host playback integration.
enum CaptionTheaterAdPlaybackState: Equatable, Sendable {
    case content
    case linearAd
    case pausePromo
    case unknown
}

/// Current subtitle-track eligibility supplied by subtitle metadata or fixture adapters.
enum CaptionTheaterSubtitleState: Equatable, Sendable {
    case webVTT
    case noneSelected
    case unsupported
    case unknown
}

/// Current viewport safety classification supplied by metadata, fixtures, or future pixel analysis.
enum CaptionTheaterViewportState: Equatable, Sendable {
    case safeCinematicLetterbox
    case fullFrame
    case unsafe
    case variableAspectRatio
    case unknown
}

/// Current protected-content policy state supplied by playback and provider metadata adapters.
enum CaptionTheaterProtectedContentState: Equatable, Sendable {
    case clearContent
    case trustedMetadataAllowed
    case protectedWithoutTrustedMetadata
    case unknown
}

/// Explainable evidence included with every eligibility decision.
///
/// Evidence stores sanitized, non-frame diagnostic text only. It must not contain credentials,
/// private stream URLs, FairPlay keys, raw protected frames, or unsanitized production manifests.
struct CaptionTheaterEvidence: Equatable, Sendable {
    let source: CaptionTheaterEvidenceSource
    let polarity: CaptionTheaterEvidencePolarity
    let message: String

    /// Creates sanitized evidence for debug inspection and tests.
    init(
        source: CaptionTheaterEvidenceSource,
        polarity: CaptionTheaterEvidencePolarity,
        message: String
    ) {
        self.source = source
        self.polarity = polarity
        self.message = message
    }

    /// Creates positive evidence supporting Caption Theater eligibility.
    static func positive(_ source: CaptionTheaterEvidenceSource, _ message: String) -> Self {
        Self(source: source, polarity: .positive, message: message)
    }

    /// Creates negative evidence proving native playback is required.
    static func negative(_ source: CaptionTheaterEvidenceSource, _ message: String) -> Self {
        Self(source: source, polarity: .negative, message: message)
    }

    /// Creates uncertain evidence that should fail closed to native playback.
    static func uncertain(_ source: CaptionTheaterEvidenceSource, _ message: String) -> Self {
        Self(source: source, polarity: .uncertain, message: message)
    }
}

/// Source area that produced a piece of Caption Theater evidence.
enum CaptionTheaterEvidenceSource: Equatable, Sendable {
    case hlsManifest
    case avFoundationMetadata
    case subtitleCueMetadata
    case timedMetadata
    case adLifecycleEvent
    case providerSideQcMetadata
    case viewportAnalysis
    case drmPolicy
    case userSetting
}

/// Direction of a piece of evidence in the final eligibility decision.
enum CaptionTheaterEvidencePolarity: Equatable, Sendable {
    case positive
    case negative
    case uncertain
}
