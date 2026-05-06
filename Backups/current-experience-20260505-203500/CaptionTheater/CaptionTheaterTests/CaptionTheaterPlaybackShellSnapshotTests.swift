//
//  CaptionTheaterPlaybackShellSnapshotTests.swift
//  CaptionTheaterTests
//
//  Behavioral coverage for playback-shell eligibility stubs (CT-0501 / CT-0502 bridge).
//

import XCTest

@testable import CaptionTheater

final class CaptionTheaterPlaybackShellSnapshotTests: XCTestCase {

    private let engine = CaptionTheaterDecisionEngine()

    func testOptOutAlwaysDisablesCaptionTheater() {
        let snapshot = CaptionTheaterPlaybackShellSnapshotBuilder.snapshot(
            captionTheaterOptInAccepted: false,
            demoAssumeWebVTTSelected: true,
            demoAssumeSafeLetterboxViewport: true
        )
        let decision = engine.decision(for: snapshot)
        guard case let .ineligible(reason, _) = decision else {
            XCTFail("Expected ineligible when user opted out")
            return
        }
        XCTAssertEqual(reason, .disabledByUser)
    }

    func testHonestStubFailsWithoutSubtitleSelection() {
        let snapshot = CaptionTheaterPlaybackShellSnapshotBuilder.snapshot(
            captionTheaterOptInAccepted: true,
            demoAssumeWebVTTSelected: false,
            demoAssumeSafeLetterboxViewport: false
        )
        let decision = engine.decision(for: snapshot)
        guard case let .ineligible(reason, _) = decision else {
            XCTFail("Expected ineligible without subtitles")
            return
        }
        XCTAssertEqual(reason, .noSubtitleTrackSelected)
    }

    func testWebVTTWithoutViewportEvidenceIsUncertain() {
        let snapshot = CaptionTheaterPlaybackShellSnapshotBuilder.snapshot(
            captionTheaterOptInAccepted: true,
            demoAssumeWebVTTSelected: true,
            demoAssumeSafeLetterboxViewport: false
        )
        let decision = engine.decision(for: snapshot)
        guard case let .uncertain(reason, _) = decision else {
            XCTFail("Expected uncertain viewport path")
            return
        }
        XCTAssertEqual(reason, .unknownViewportSafety)
    }

    func testDemoTogglesReachEligible() {
        let snapshot = CaptionTheaterPlaybackShellSnapshotBuilder.snapshot(
            captionTheaterOptInAccepted: true,
            demoAssumeWebVTTSelected: true,
            demoAssumeSafeLetterboxViewport: true
        )
        let decision = engine.decision(for: snapshot)
        guard case .eligible = decision else {
            XCTFail("Expected eligible when demo gates supply sufficient evidence")
            return
        }
    }
}
