import Foundation
import Testing
@testable import CaptionTheater

struct SubtitleMetadataClassifierTests {

    /// Verifies that sidecar WebVTT dialogue is the first persistence-compatible subtitle path.
    @Test func sidecarWebVTTDialogueIsPersistenceEligible() throws {
        let classification = try classifyFixture(named: "sidecar-webvtt-dialogue")

        #expect(classification.subtitleState == .webVTT)
        #expect(classification.presentationPolicy == .persistentCueEligible)
        #expect(classification.track?.kind == .dialogue)

        let decision = CaptionTheaterDecisionEngine().decision(
            for: eligibilitySnapshot(subtitleState: classification.subtitleState, evidence: classification.evidence)
        )
        guard case .eligible = decision else {
            Issue.record("Expected WebVTT dialogue classification to support eligible decision, got \(decision).")
            return
        }
    }

    /// Verifies that sidecar WebVTT SDH tracks are eligible for previous-cue retention.
    @Test func sidecarWebVTTSDHIsPersistenceEligible() throws {
        let classification = try classifyFixture(named: "sidecar-webvtt-sdh")

        #expect(classification.subtitleState == .webVTT)
        #expect(classification.presentationPolicy == .persistentCueEligible)
        #expect(classification.track?.kind == .sdh)
    }

    /// Verifies that forced WebVTT cues are identified as authored-timing-only by default.
    @Test func forcedWebVTTIsAuthoredTimingOnly() throws {
        let classification = try classifyFixture(named: "sidecar-webvtt-forced")

        #expect(classification.subtitleState == .webVTT)
        #expect(classification.presentationPolicy == .authoredTimingOnly)
        #expect(classification.track?.isForced == true)
        #expect(classification.track?.preserveAuthoredPlacement == true)
    }

    /// Verifies that embedded captions stay native-only until semantic extraction exists.
    @Test func embeddedClosedCaptionsAreNativeOnly() throws {
        let classification = try classifyFixture(named: "embedded-cea608")

        #expect(classification.subtitleState == .unsupported)
        #expect(classification.presentationPolicy == .nativeOnly)
        #expect(classification.track?.transport == .embeddedClosedCaptions)
        #expect(classification.evidence.contains { $0.polarity == .negative })
    }

    /// Verifies that image-based subtitle formats are not treated as reflowable text.
    @Test func imageBasedSubtitlesAreNativeOnly() throws {
        let classification = try classifyFixture(named: "image-based-subtitle")

        #expect(classification.subtitleState == .unsupported)
        #expect(classification.presentationPolicy == .nativeOnly)
        #expect(classification.track?.isImageBased == true)
    }

    /// Verifies that burned-in subtitles are visual content, not selected caption data.
    @Test func burnedInSubtitlesAreNotCaptionData() throws {
        let classification = try classifyFixture(named: "burned-in-subtitles")

        #expect(classification.subtitleState == .unsupported)
        #expect(classification.presentationPolicy == .nativeOnly)
        #expect(classification.track?.isBurnedIn == true)
    }

    /// Verifies that missing selected subtitle metadata becomes a no-track decision input.
    @Test func missingSelectedTrackIsNativeOnly() throws {
        let classification = try classifyFixture(named: "missing-selected-track")

        #expect(classification.subtitleState == .noneSelected)
        #expect(classification.presentationPolicy == .nativeOnly)
        #expect(classification.track == nil)
    }

    /// Verifies that unknown subtitle formats fail closed.
    @Test func unknownSubtitleFormatFailsClosed() throws {
        let classification = try classifyFixture(named: "unknown-format")

        #expect(classification.subtitleState == .unknown)
        #expect(classification.presentationPolicy == .nativeOnly)
        #expect(classification.evidence.contains { $0.polarity == .uncertain })
    }

    private func classifyFixture(named name: String) throws -> SubtitleMetadataClassification {
        let document = try SubtitleMetadataFixture.load(named: name)
        return SubtitleMetadataClassifier().classify(document)
    }

    private func eligibilitySnapshot(
        subtitleState: CaptionTheaterSubtitleState,
        evidence: [CaptionTheaterEvidence]
    ) -> CaptionTheaterEligibilitySnapshot {
        CaptionTheaterEligibilitySnapshot(
            isEnabledByUser: true,
            adPlaybackState: .content,
            subtitleState: subtitleState,
            viewportState: .safeCinematicLetterbox,
            protectedContentState: .clearContent,
            evidence: evidence
        )
    }
}

/// Loads sanitized subtitle metadata fixtures from the unit test bundle.
private enum SubtitleMetadataFixture {
    /// Returns the decoded subtitle metadata document for a resource name without its `.json` extension.
    static func load(named name: String) throws -> SubtitleMetadataDocument {
        let bundle = Bundle(for: SubtitleMetadataFixtureBundleToken.self)
        guard let fixtureURL = bundle.url(forResource: name, withExtension: "json") else {
            throw SubtitleMetadataFixtureLoadingError.missingResource("\(name).json")
        }

        let data = try Data(contentsOf: fixtureURL)
        return try SubtitleMetadataClassifier().decode(data)
    }
}

/// Provides a stable Objective-C runtime anchor for locating the unit test bundle.
private final class SubtitleMetadataFixtureBundleToken: NSObject {}

/// Errors that can occur before subtitle metadata fixture parsing begins.
private enum SubtitleMetadataFixtureLoadingError: Error, Sendable {
    case missingResource(String)
}
