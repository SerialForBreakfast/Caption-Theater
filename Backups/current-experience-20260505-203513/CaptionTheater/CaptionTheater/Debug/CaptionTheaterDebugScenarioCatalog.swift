//
//  CaptionTheaterDebugScenarioCatalog.swift
//  CaptionTheater
//
//  Deterministic eligibility snapshots for the debug inspector (no AVPlayer, no bundled JSON).
//

import Foundation

/// A named eligibility snapshot used only by ``CaptionTheaterDebugDecisionInspectorView``.
///
/// These scenarios mirror the unit-test matrix so Product and QA can read outcomes on-device.
/// Snapshots are built in code to avoid duplicating JSON fixtures in the app bundle.
struct CaptionTheaterDebugScenario: Identifiable, Sendable {
    let id: String
    /// Short title for lists and navigation.
    let title: String
    /// One-line intent for readers who are not familiar with engine internals.
    let summary: String
    /// Inputs evaluated by ``CaptionTheaterDecisionEngine``.
    let snapshot: CaptionTheaterEligibilitySnapshot
}

/// Static catalog of debug scenarios.
enum CaptionTheaterDebugScenarioCatalog {
    /// Preordered scenarios for stable navigation focus order on tvOS.
    static let scenarios: [CaptionTheaterDebugScenario] = [
        CaptionTheaterDebugScenario(
            id: "eligible-baseline",
            title: "Eligible baseline",
            summary: "Ultra-widescreen-safe viewport, WebVTT, clear content, ads inactive.",
            snapshot: makeSnapshot()
        ),
        CaptionTheaterDebugScenario(
            id: "user-disabled",
            title: "User disabled Caption Theater",
            summary: "User preference forces native playback before other evidence is considered.",
            snapshot: makeSnapshot(isEnabledByUser: false)
        ),
        CaptionTheaterDebugScenario(
            id: "linear-ad",
            title: "Linear ad playback",
            summary: "Active linear ad requires fullscreen/native presentation.",
            snapshot: makeSnapshot(adPlaybackState: .linearAd)
        ),
        CaptionTheaterDebugScenario(
            id: "pause-promo",
            title: "Pause promo",
            summary: "Pause promotional surfaces are not eligible for Caption Theater layout.",
            snapshot: makeSnapshot(adPlaybackState: .pausePromo)
        ),
        CaptionTheaterDebugScenario(
            id: "unknown-ad",
            title: "Unknown ad state",
            summary: "Incomplete ad lifecycle evidence fails closed (uncertain).",
            snapshot: makeSnapshot(adPlaybackState: .unknown)
        ),
        CaptionTheaterDebugScenario(
            id: "unsupported-subtitle",
            title: "Unsupported subtitle format",
            summary: "Selected track cannot participate in persistence policy.",
            snapshot: makeSnapshot(subtitleState: .unsupported)
        ),
        CaptionTheaterDebugScenario(
            id: "no-subtitle-selected",
            title: "No subtitle selected",
            summary: "Missing selection keeps native captions path.",
            snapshot: makeSnapshot(subtitleState: .noneSelected)
        ),
        CaptionTheaterDebugScenario(
            id: "unknown-subtitle",
            title: "Unknown subtitle classification",
            summary: "Classifier cannot prove eligibility for the selected track.",
            snapshot: makeSnapshot(subtitleState: .unknown)
        ),
        CaptionTheaterDebugScenario(
            id: "unsafe-viewport",
            title: "Unsafe inactive region",
            summary: "Inactive-looking bands contain unsafe visual evidence.",
            snapshot: makeSnapshot(viewportState: .unsafe)
        ),
        CaptionTheaterDebugScenario(
            id: "full-frame",
            title: "Full-frame 16:9",
            summary: "No useful inactive caption region for theater layout.",
            snapshot: makeSnapshot(viewportState: .fullFrame)
        ),
        CaptionTheaterDebugScenario(
            id: "variable-aspect",
            title: "Variable aspect ratio",
            summary: "Timeline aspect changes keep MVP on native playback.",
            snapshot: makeSnapshot(viewportState: .variableAspectRatio)
        ),
        CaptionTheaterDebugScenario(
            id: "unknown-viewport",
            title: "Unknown viewport safety",
            summary: "Viewport analysis cannot prove a safe letterbox band.",
            snapshot: makeSnapshot(viewportState: .unknown)
        ),
        CaptionTheaterDebugScenario(
            id: "drm-without-trusted-metadata",
            title: "Protected content, no trusted metadata",
            summary: "DRM-like presentation without QC/trusted metadata fails closed.",
            snapshot: makeSnapshot(protectedContentState: .protectedWithoutTrustedMetadata)
        ),
        CaptionTheaterDebugScenario(
            id: "drm-unknown",
            title: "Unknown protected-content policy",
            summary: "Playback cannot classify protection state.",
            snapshot: makeSnapshot(protectedContentState: .unknown)
        ),
        CaptionTheaterDebugScenario(
            id: "trusted-metadata-eligible",
            title: "Trusted metadata + protected allowance",
            summary: "Representative fixture path where QC metadata authorizes protected eligibility.",
            snapshot: makeSnapshot(protectedContentState: .trustedMetadataAllowed)
        ),
    ]
}

private func makeSnapshot(
    isEnabledByUser: Bool = true,
    adPlaybackState: CaptionTheaterAdPlaybackState = .content,
    subtitleState: CaptionTheaterSubtitleState = .webVTT,
    viewportState: CaptionTheaterViewportState = .safeCinematicLetterbox,
    protectedContentState: CaptionTheaterProtectedContentState = .clearContent
) -> CaptionTheaterEligibilitySnapshot {
    CaptionTheaterEligibilitySnapshot(
        isEnabledByUser: isEnabledByUser,
        adPlaybackState: adPlaybackState,
        subtitleState: subtitleState,
        viewportState: viewportState,
        protectedContentState: protectedContentState
    )
}
