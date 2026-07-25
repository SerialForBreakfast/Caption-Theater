//
//  CaptionTheaterCaptionRendererPlanTests.swift
//  CaptionTheaterTests
//

import Foundation
import Testing

@testable import CaptionTheater

struct CaptionTheaterCaptionRendererPlanTests {

    @Test func currentOnlyRowIsFullyOpaqueWithStandardLineBudget() {
        let plan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: [row("A", state: .current, text: "Current line")],
            textSizePreset: .standard,
            isPlaybackPaused: false
        )

        #expect(plan.emptyReason == nil)
        #expect(plan.rows.count == 1)
        #expect(plan.rows[0].emphasis == .current)
        #expect(plan.rows[0].opacity == 1)
        #expect(plan.rows[0].maximumLines == 8)
    }

    @Test func retainedRowIsDeemphasizedRelativeToCurrent() {
        let plan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: [
                row("A", state: .current, text: "Current"),
                row("B", state: .retained, text: "Retained")
            ],
            textSizePreset: .standard,
            isPlaybackPaused: false
        )

        #expect(plan.rows.map(\.emphasis) == [.current, .retained])
        #expect(plan.rows[1].opacity < plan.rows[0].opacity)
        #expect(plan.rows[1].maximumLines < plan.rows[0].maximumLines)
    }

    @Test func largeTextPresetsReduceLineBudgetToAvoidTranscriptWall() {
        let standardPlan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: [row("A", state: .retained, text: "Retained")],
            textSizePreset: .standard,
            isPlaybackPaused: false
        )
        let maxReadabilityPlan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: [row("A", state: .retained, text: "Retained")],
            textSizePreset: .maxReadability,
            isPlaybackPaused: false
        )

        #expect(maxReadabilityPlan.rows[0].maximumLines < standardPlan.rows[0].maximumLines)
    }

    @Test func clearedHistoryWhilePlayingShowsWaitingMessage() {
        let plan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: [],
            textSizePreset: .standard,
            isPlaybackPaused: false
        )

        #expect(plan.isEmpty)
        #expect(plan.emptyReason == .waitingForCues)
    }

    @Test func clearedHistoryWhilePausedExplainsPauseRatherThanWaiting() {
        let plan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: [],
            textSizePreset: .standard,
            isPlaybackPaused: true
        )

        #expect(plan.isEmpty)
        #expect(plan.emptyReason == .playbackPaused)
    }

    @Test func rowIdentityAndTextArePreservedFromUpstreamCueRows() {
        let upstream = row("A", state: .current, text: "Hello there")
        let plan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: [upstream],
            textSizePreset: .large,
            isPlaybackPaused: false
        )

        #expect(plan.rows[0].id == upstream.id)
        #expect(plan.rows[0].text == "Hello there")
    }

    private func row(
        _ cueID: String,
        state: CaptionTheaterVisibleCueRowState,
        text: String
    ) -> CaptionTheaterVisibleCueRow {
        CaptionTheaterVisibleCueRow(
            cue: CaptionTheaterCue(id: cueID, startSeconds: 0, endSeconds: 1, text: text),
            state: state
        )
    }
}
