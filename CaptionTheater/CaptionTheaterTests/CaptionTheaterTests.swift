//
//  CaptionTheaterTests.swift
//  CaptionTheaterTests
//
//  Created by Joseph McCraw on 5/5/26.
//

import Testing
@testable import CaptionTheater

struct CaptionTheaterTests {

    /// Verifies that a fully supported fixture snapshot activates Caption Theater.
    @Test func eligibleSnapshotActivatesCaptionTheater() {
        let decision = engine.decision(for: eligibleSnapshot())

        guard case let .eligible(evidence) = decision else {
            Issue.record("Expected eligible decision, got \(decision).")
            return
        }

        #expect(evidence.contains { $0.source == .viewportAnalysis && $0.polarity == .positive })
        #expect(evidence.contains { $0.source == .subtitleCueMetadata && $0.polarity == .positive })
    }

    /// Verifies that user control wins before any other eligibility evidence is considered.
    @Test func userDisablementForcesNativePlayback() {
        let decision = engine.decision(
            for: eligibleSnapshot(isEnabledByUser: false)
        )

        guard case let .ineligible(reason, evidence) = decision else {
            Issue.record("Expected ineligible decision, got \(decision).")
            return
        }

        #expect(reason == .disabledByUser)
        #expect(evidence.contains { $0.source == .userSetting && $0.polarity == .negative })
    }

    /// Verifies that linear ads keep their native fullscreen presentation.
    @Test func linearAdForcesNativePlayback() {
        let decision = engine.decision(
            for: eligibleSnapshot(adPlaybackState: .linearAd)
        )

        guard case let .ineligible(reason, evidence) = decision else {
            Issue.record("Expected ineligible decision, got \(decision).")
            return
        }

        #expect(reason == .adPlaybackActive)
        #expect(evidence.contains { $0.source == .adLifecycleEvent && $0.polarity == .negative })
    }

    /// Verifies that unknown ad state fails closed instead of allowing Caption Theater.
    @Test func unknownAdStateIsUncertain() {
        let decision = engine.decision(
            for: eligibleSnapshot(adPlaybackState: .unknown)
        )

        guard case let .uncertain(reason, evidence) = decision else {
            Issue.record("Expected uncertain decision, got \(decision).")
            return
        }

        #expect(reason == .unknownAdPlaybackState)
        #expect(evidence.contains { $0.source == .adLifecycleEvent && $0.polarity == .uncertain })
    }

    /// Verifies that unsupported subtitle formats do not enter persistence mode.
    @Test func unsupportedSubtitleFormatForcesNativePlayback() {
        let decision = engine.decision(
            for: eligibleSnapshot(subtitleState: .unsupported)
        )

        guard case let .ineligible(reason, evidence) = decision else {
            Issue.record("Expected ineligible decision, got \(decision).")
            return
        }

        #expect(reason == .unsupportedSubtitleFormat)
        #expect(evidence.contains { $0.source == .subtitleCueMetadata && $0.polarity == .negative })
    }

    /// Verifies that unsafe visual evidence in inactive-looking regions forces native playback.
    @Test func unsafeViewportRegionForcesNativePlayback() {
        let decision = engine.decision(
            for: eligibleSnapshot(viewportState: .unsafe)
        )

        guard case let .ineligible(reason, evidence) = decision else {
            Issue.record("Expected ineligible decision, got \(decision).")
            return
        }

        #expect(reason == .unsafeViewportRegion)
        #expect(evidence.contains { $0.source == .viewportAnalysis && $0.polarity == .negative })
    }

    /// Verifies that protected playback requires trusted metadata before activation.
    @Test func protectedContentWithoutTrustedMetadataIsUncertain() {
        let decision = engine.decision(
            for: eligibleSnapshot(protectedContentState: .protectedWithoutTrustedMetadata)
        )

        guard case let .uncertain(reason, evidence) = decision else {
            Issue.record("Expected uncertain decision, got \(decision).")
            return
        }

        #expect(reason == .protectedContentRequiresTrustedMetadata)
        #expect(evidence.contains { $0.source == .drmPolicy && $0.polarity == .uncertain })
    }

    private var engine: CaptionTheaterDecisionEngine {
        CaptionTheaterDecisionEngine()
    }

    private func eligibleSnapshot(
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

}
