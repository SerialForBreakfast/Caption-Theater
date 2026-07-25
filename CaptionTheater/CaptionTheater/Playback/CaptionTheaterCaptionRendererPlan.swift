//
//  CaptionTheaterCaptionRendererPlan.swift
//  CaptionTheater
//
//  Pure, SwiftUI-independent rendering plan for the Caption Theater caption band (CT-0404). Separated from
//  CaptionTheaterCaptionRendererView so presentation rules (emphasis, empty-state messaging, text-density
//  budgeting) stay unit-testable without AVPlayer or a hosted view hierarchy.
//

import Foundation

/// Visual emphasis for a rendered caption row.
///
/// Mirrors ``CaptionTheaterVisibleCueRowState`` but stays a distinct type so the renderer's presentation rules
/// (line budgets, styling) can evolve independently of the upstream cue-persistence policy.
enum CaptionTheaterCaptionRenderEmphasis: Equatable, Sendable {
    case current
    case retained
}

/// One render-ready caption row: text plus every presentation decision needed to draw it.
struct CaptionTheaterCaptionRenderRow: Identifiable, Equatable, Sendable {

    let id: String
    let text: String
    let emphasis: CaptionTheaterCaptionRenderEmphasis

    /// Retained rows are visibly de-emphasized; current is always fully opaque.
    let opacity: Double

    /// Maximum lines before `minimumScaleFactor` takes over, tuned per ``CaptionTheaterCaptionTextSizePreset`` so
    /// larger text presets never overflow the caption reading band into a transcript wall.
    let maximumLines: Int
}

/// Why the caption band is empty right now, so the UI can explain the blank state rather than looking broken.
enum CaptionTheaterCaptionRenderEmptyReason: Equatable, Sendable {
    case waitingForCues
    case playbackPaused
}

/// Fully computed description of what the caption band should show at one instant. SwiftUI-free by design.
struct CaptionTheaterCaptionRenderPlan: Equatable, Sendable {

    let rows: [CaptionTheaterCaptionRenderRow]
    let emptyReason: CaptionTheaterCaptionRenderEmptyReason?

    var isEmpty: Bool { rows.isEmpty }
}

enum CaptionTheaterCaptionRendererPolicy {

    /// Line budgets per text-size preset. Larger presets intentionally allow fewer lines per row so a wider glyph
    /// size still fits the caption reading band; the remainder is handled by `minimumScaleFactor` at the view layer.
    private static func maximumLines(
        for preset: CaptionTheaterCaptionTextSizePreset,
        emphasis: CaptionTheaterCaptionRenderEmphasis
    ) -> Int {
        switch (preset, emphasis) {
        case (.standard, .current), (.large, .current):
            return 8
        case (.standard, .retained), (.large, .retained):
            return 4
        case (.extraLarge, .current), (.maxReadability, .current):
            return 5
        case (.extraLarge, .retained), (.maxReadability, .retained):
            return 2
        }
    }

    /// Builds the render plan for one playback instant.
    ///
    /// Never introduces future cues — that guarantee lives upstream in ``CaptionTheaterCuePersistencePolicyEngine``;
    /// this stage only maps already-visible rows into presentation (emphasis styling, per-preset line budgets) and
    /// empty-state messaging so a blank band reads as "waiting" or "paused" rather than a bug.
    static func plan(
        rows visibleRows: [CaptionTheaterVisibleCueRow],
        textSizePreset: CaptionTheaterCaptionTextSizePreset,
        isPlaybackPaused: Bool
    ) -> CaptionTheaterCaptionRenderPlan {
        guard !visibleRows.isEmpty else {
            return CaptionTheaterCaptionRenderPlan(
                rows: [],
                emptyReason: isPlaybackPaused ? .playbackPaused : .waitingForCues
            )
        }

        let renderRows = visibleRows.map { row -> CaptionTheaterCaptionRenderRow in
            let emphasis: CaptionTheaterCaptionRenderEmphasis = row.state == .current ? .current : .retained
            return CaptionTheaterCaptionRenderRow(
                id: row.id,
                text: row.text,
                emphasis: emphasis,
                opacity: emphasis == .current ? 1 : 0.72,
                maximumLines: maximumLines(for: textSizePreset, emphasis: emphasis)
            )
        }

        return CaptionTheaterCaptionRenderPlan(rows: renderRows, emptyReason: nil)
    }
}
