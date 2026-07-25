//
//  CaptionTheaterCuePersistencePolicyTests.swift
//  CaptionTheaterTests
//

import Foundation
import Testing

@testable import CaptionTheater

struct CaptionTheaterCuePersistencePolicyTests {

    @Test func currentCueAppearsDuringAuthoredTiming() {
        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(
            cues: [cue("A", start: 1, end: 4, text: "Current")],
            playbackSeconds: 2
        )

        #expect(rows == [
            CaptionTheaterVisibleCueRow(cue: cue("A", start: 1, end: 4, text: "Current"), state: .current)
        ])
    }

    @Test func futureCueNeverAppears() {
        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(
            cues: [
                cue("A", start: 10, end: 14, text: "Future")
            ],
            playbackSeconds: 5
        )

        #expect(rows.isEmpty)
    }

    @Test func expiredEligibleCuePersistsWithinAgeBound() {
        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(
            cues: [cue("A", start: 1, end: 3, text: "Retained")],
            playbackSeconds: 8,
            configuration: CaptionTheaterCuePersistenceConfiguration(
                retainedCueMaximumAgeSeconds: 10,
                maximumVisibleRows: 3,
                retainedCharacterBudget: 100
            )
        )

        #expect(rows.count == 1)
        #expect(rows[0].state == .retained)
        #expect(rows[0].text == "Retained")
    }

    @Test func expiredCueFallsOutAfterAgeBound() {
        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(
            cues: [cue("A", start: 1, end: 3, text: "Too old")],
            playbackSeconds: 20,
            configuration: CaptionTheaterCuePersistenceConfiguration(
                retainedCueMaximumAgeSeconds: 10,
                maximumVisibleRows: 3,
                retainedCharacterBudget: 100
            )
        )

        #expect(rows.isEmpty)
    }

    @Test func rowCountAndCharacterBudgetPreventTranscriptWall() {
        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(
            cues: [
                cue("A", start: 1, end: 2, text: "One"),
                cue("B", start: 3, end: 4, text: "Two"),
                cue("C", start: 5, end: 6, text: "This cue exceeds budget")
            ],
            playbackSeconds: 8,
            configuration: CaptionTheaterCuePersistenceConfiguration(
                retainedCueMaximumAgeSeconds: 20,
                maximumVisibleRows: 2,
                retainedCharacterBudget: 10
            )
        )

        #expect(rows.map(\.text) == ["Two", "One"])
        #expect(rows.allSatisfy { $0.state == .retained })
    }

    @Test func currentCuePresentationPrecedesRetainedRows() {
        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(
            cues: [
                cue("A", start: 1, end: 3, text: "Older"),
                cue("B", start: 5, end: 9, text: "Current")
            ],
            playbackSeconds: 6,
            configuration: CaptionTheaterCuePersistenceConfiguration(
                retainedCueMaximumAgeSeconds: 10,
                maximumVisibleRows: 3,
                retainedCharacterBudget: 100
            )
        )

        #expect(rows.map(\.text) == ["Current", "Older"])
        #expect(rows.map(\.state) == [.current, .retained])
    }

    @Test func authoredTimingOnlyCueDoesNotPersist() {
        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(
            cues: [
                cue(
                    "FORCED",
                    start: 1,
                    end: 2,
                    text: "Sign text",
                    intent: .forced,
                    persistencePolicy: .authoredTimingOnly
                )
            ],
            playbackSeconds: 3
        )

        #expect(rows.isEmpty)
    }

    @Test func clearOnSeekEquivalentStartsFromCurrentPlaybackTimeOnly() {
        let cues = [
            cue("A", start: 1, end: 2, text: "Old"),
            cue("B", start: 30, end: 32, text: "After seek")
        ]

        let rows = CaptionTheaterCuePersistencePolicyEngine.visibleRows(cues: cues, playbackSeconds: 30.5)

        #expect(rows.map(\.text) == ["After seek"])
        #expect(rows.map(\.state) == [.current])
    }

    private func cue(
        _ id: String,
        start: Double,
        end: Double,
        text: String,
        intent: CaptionTheaterCueIntent = .dialogue,
        persistencePolicy: CaptionTheaterCuePersistencePolicy = .eligibleForRetention
    ) -> CaptionTheaterCue {
        CaptionTheaterCue(
            id: id,
            startSeconds: start,
            endSeconds: end,
            text: text,
            intent: intent,
            persistencePolicy: persistencePolicy
        )
    }
}
