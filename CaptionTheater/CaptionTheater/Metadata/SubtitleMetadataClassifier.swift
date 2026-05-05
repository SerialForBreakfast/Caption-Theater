import Foundation

/// Classifies sanitized subtitle metadata into Caption Theater eligibility inputs.
///
/// `SubtitleMetadataClassifier` is stateless, synchronous, and nonisolated. It only evaluates already
/// available metadata from fixtures, manifests, or future subtitle adapters; it does not load media,
/// fetch subtitle files, parse cue payloads, or render captions.
nonisolated struct SubtitleMetadataClassifier: Sendable {
    /// Creates a classifier with no retained state.
    init() {}

    /// Decodes local subtitle metadata JSON into a typed fixture document.
    func decode(_ data: Data) throws -> SubtitleMetadataDocument {
        try JSONDecoder().decode(SubtitleMetadataDocument.self, from: data)
    }

    /// Classifies the selected subtitle track, failing closed for missing or unsupported semantics.
    func classify(_ document: SubtitleMetadataDocument) -> SubtitleMetadataClassification {
        guard let track = document.selectedTrack else {
            return SubtitleMetadataClassification(
                track: nil,
                subtitleState: .noneSelected,
                presentationPolicy: .nativeOnly,
                evidence: [.negative(.subtitleCueMetadata, "No selected subtitle track is available.")]
            )
        }

        var evidence = [
            CaptionTheaterEvidence(
                source: .subtitleCueMetadata,
                polarity: .positive,
                message: "Selected subtitle track \(track.identifier) declares format \(track.format.rawValue)."
            )
        ]

        if track.isBurnedIn || track.transport == .burnedIn {
            evidence.append(.negative(.subtitleCueMetadata, "Burned-in subtitles are visual content, not reflowable caption data."))
            return SubtitleMetadataClassification(
                track: track,
                subtitleState: .unsupported,
                presentationPolicy: .nativeOnly,
                evidence: evidence
            )
        }

        if track.isImageBased || track.format == .imageBased {
            evidence.append(.negative(.subtitleCueMetadata, "Image-based subtitles must preserve native authored presentation."))
            return SubtitleMetadataClassification(
                track: track,
                subtitleState: .unsupported,
                presentationPolicy: .nativeOnly,
                evidence: evidence
            )
        }

        if track.transport == .embeddedClosedCaptions {
            evidence.append(.negative(.subtitleCueMetadata, "Embedded closed captions remain native-only until semantic extraction exists."))
            return SubtitleMetadataClassification(
                track: track,
                subtitleState: .unsupported,
                presentationPolicy: .nativeOnly,
                evidence: evidence
            )
        }

        guard track.format == .webVTT, track.transport == .sidecarText else {
            evidence.append(.uncertain(.subtitleCueMetadata, "Subtitle format or transport is not yet supported by the MVP classifier."))
            return SubtitleMetadataClassification(
                track: track,
                subtitleState: track.format == .unknown ? .unknown : .unsupported,
                presentationPolicy: .nativeOnly,
                evidence: evidence
            )
        }

        if track.isForced || track.preserveAuthoredPlacement || track.kind.requiresAuthoredTimingOnly {
            evidence.append(.positive(.subtitleCueMetadata, "WebVTT is parseable, but cue intent requires authored timing only."))
            return SubtitleMetadataClassification(
                track: track,
                subtitleState: .webVTT,
                presentationPolicy: .authoredTimingOnly,
                evidence: evidence
            )
        }

        guard track.supportsCaptionTheater, track.supportsPreviousCueRetention else {
            evidence.append(.negative(.subtitleCueMetadata, "Subtitle metadata does not allow Caption Theater persistence."))
            return SubtitleMetadataClassification(
                track: track,
                subtitleState: .unsupported,
                presentationPolicy: .nativeOnly,
                evidence: evidence
            )
        }

        evidence.append(.positive(.subtitleCueMetadata, "Sidecar WebVTT supports previous-cue retention."))
        return SubtitleMetadataClassification(
            track: track,
            subtitleState: .webVTT,
            presentationPolicy: .persistentCueEligible,
            evidence: evidence
        )
    }
}

/// Local subtitle metadata document used by fixture and adapter inputs.
nonisolated struct SubtitleMetadataDocument: Codable, Equatable, Sendable {
    let selectedTrack: SubtitleTrackMetadata?
}

/// Sanitized metadata describing a selected subtitle or caption track.
nonisolated struct SubtitleTrackMetadata: Codable, Equatable, Sendable {
    let identifier: String
    let language: String?
    let format: SubtitleTrackFormat
    let transport: SubtitleTrackTransport
    let kind: SubtitleTrackKind
    let isForced: Bool
    let isImageBased: Bool
    let isBurnedIn: Bool
    let supportsCaptionTheater: Bool
    let supportsPreviousCueRetention: Bool
    let preserveAuthoredPlacement: Bool
}

/// Result of classifying selected subtitle metadata for Caption Theater.
nonisolated struct SubtitleMetadataClassification: Equatable, Sendable {
    let track: SubtitleTrackMetadata?
    let subtitleState: CaptionTheaterSubtitleState
    let presentationPolicy: SubtitlePresentationPolicy
    let evidence: [CaptionTheaterEvidence]
}

/// Subtitle formats the metadata layer can distinguish before cue parsing exists.
nonisolated enum SubtitleTrackFormat: String, Codable, Equatable, Sendable {
    case webVTT
    case imscTTML
    case cea608
    case cea708
    case imageBased
    case unknown
}

/// How subtitle data is transported or represented.
nonisolated enum SubtitleTrackTransport: String, Codable, Equatable, Sendable {
    case sidecarText
    case embeddedClosedCaptions
    case imageBased
    case burnedIn
    case unknown
}

/// High-level cue intent used to avoid unsafe persistence decisions before cue parsing exists.
nonisolated enum SubtitleTrackKind: String, Codable, Equatable, Sendable {
    case dialogue
    case sdh
    case forced
    case lyrics
    case legal
    case ad
    case unknown

    /// Whether this track kind should avoid retained cue history by default.
    var requiresAuthoredTimingOnly: Bool {
        switch self {
        case .forced, .lyrics, .legal, .ad, .unknown:
            true
        case .dialogue, .sdh:
            false
        }
    }
}

/// Caption Theater presentation policy implied by subtitle metadata.
nonisolated enum SubtitlePresentationPolicy: String, Codable, Equatable, Sendable {
    case persistentCueEligible
    case authoredTimingOnly
    case nativeOnly
}
