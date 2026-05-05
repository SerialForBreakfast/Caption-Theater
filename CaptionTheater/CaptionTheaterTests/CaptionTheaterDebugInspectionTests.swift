//
//  CaptionTheaterDebugInspectionTests.swift
//  CaptionTheaterTests
//
//  Covers debug inspection copy wiring without exercising SwiftUI.
//

import Testing
@testable import CaptionTheater

struct CaptionTheaterDebugInspectionTests {

    @Test func baselineScenarioProducesEligibleHeadline() {
        let scenario = CaptionTheaterDebugScenarioCatalog.scenarios.first { $0.id == "eligible-baseline" }
        #expect(scenario != nil)
        guard let scenario else { return }

        let decision = CaptionTheaterDecisionEngine().decision(for: scenario.snapshot)
        let inspection = CaptionTheaterDebugDecisionInspection(
            scenarioTitle: scenario.title,
            scenarioSummary: scenario.summary,
            snapshot: scenario.snapshot,
            decision: decision
        )

        #expect(inspection.outcomeHeadline == "Caption Theater eligible")
        #expect(inspection.inputRows.contains { $0.label == "Ad playback state" })
    }

    @Test func linearAdScenarioProducesIneligibleHeadline() {
        let scenario = CaptionTheaterDebugScenarioCatalog.scenarios.first { $0.id == "linear-ad" }
        #expect(scenario != nil)
        guard let scenario else { return }

        let decision = CaptionTheaterDecisionEngine().decision(for: scenario.snapshot)
        let inspection = CaptionTheaterDebugDecisionInspection(
            scenarioTitle: scenario.title,
            scenarioSummary: scenario.summary,
            snapshot: scenario.snapshot,
            decision: decision
        )

        #expect(inspection.outcomeHeadline == "Native playback (ineligible)")
        #expect(inspection.outcomeDetail.contains("adPlayback"))
    }

    @Test func unknownAdScenarioProducesUncertainHeadline() {
        let scenario = CaptionTheaterDebugScenarioCatalog.scenarios.first { $0.id == "unknown-ad" }
        #expect(scenario != nil)
        guard let scenario else { return }

        let decision = CaptionTheaterDecisionEngine().decision(for: scenario.snapshot)
        let inspection = CaptionTheaterDebugDecisionInspection(
            scenarioTitle: scenario.title,
            scenarioSummary: scenario.summary,
            snapshot: scenario.snapshot,
            decision: decision
        )

        #expect(inspection.outcomeHeadline.contains("Uncertain"))
    }
}
