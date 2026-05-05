import Foundation
import Testing
@testable import CaptionTheater

struct ProviderMetadataInspectorTests {

    /// Verifies that trusted provider QC metadata can authorize protected-content eligibility.
    @Test func trustedEligibleMetadataAllowsProtectedDecisionPath() throws {
        let inspection = try inspectFixture(named: "trusted-eligible-letterbox")

        #expect(inspection.protectedContentState == .trustedMetadataAllowed)
        #expect(inspection.viewportState == .safeCinematicLetterbox)
        #expect(inspection.metadata?.declaredActiveAspectRatio == 2.3529)
        #expect(inspection.metadata?.activePictureRect?.height == 816)
        #expect(inspection.metadata?.safeCaptionRegions.first?.y == 948)

        let decision = CaptionTheaterDecisionEngine().decision(for: inspection.eligibilitySnapshot())
        guard case .eligible = decision else {
            Issue.record("Expected trusted provider metadata to produce eligible decision, got \(decision).")
            return
        }
    }

    /// Verifies that missing metadata fails closed for protected content.
    @Test func missingMetadataKeepsProtectedContentNative() {
        let inspection = ProviderMetadataInspector().inspect(nil)

        #expect(inspection.protectedContentState == .protectedWithoutTrustedMetadata)
        #expect(inspection.viewportState == .unknown)

        let decision = CaptionTheaterDecisionEngine().decision(for: inspection.eligibilitySnapshot())
        guard case let .uncertain(reason, evidence) = decision else {
            Issue.record("Expected missing metadata to be uncertain, got \(decision).")
            return
        }

        #expect(reason == .protectedContentRequiresTrustedMetadata)
        #expect(evidence.contains { $0.source == .drmPolicy && $0.polarity == .uncertain })
    }

    /// Verifies that provider blocklist metadata overrides otherwise positive assumptions.
    @Test func blocklistMetadataForcesNativeDecisionPath() throws {
        let inspection = try inspectFixture(named: "blocklisted-burned-in-subtitles")

        #expect(inspection.protectedContentState == .trustedMetadataAllowed)
        #expect(inspection.viewportState == .unsafe)
        #expect(inspection.metadata?.warnings == [.burnedInSubtitleRisk])

        let decision = CaptionTheaterDecisionEngine().decision(for: inspection.eligibilitySnapshot())
        guard case let .ineligible(reason, evidence) = decision else {
            Issue.record("Expected blocklisted metadata to be ineligible, got \(decision).")
            return
        }

        #expect(reason == .unsafeViewportRegion)
        #expect(evidence.contains { $0.source == .providerSideQcMetadata && $0.polarity == .negative })
    }

    /// Verifies variable-aspect warnings map to native viewport classification.
    @Test func variableAspectWarningForcesNativeViewportClassification() throws {
        let inspection = try inspectFixture(named: "variable-aspect-warning")

        #expect(inspection.viewportState == .variableAspectRatio)
        #expect(inspection.metadata?.warnings == [.variableAspectRatio])

        let decision = CaptionTheaterDecisionEngine().decision(for: inspection.eligibilitySnapshot())
        guard case let .ineligible(reason, _) = decision else {
            Issue.record("Expected variable aspect metadata to be ineligible, got \(decision).")
            return
        }

        #expect(reason == .variableAspectRatio)
    }

    /// Verifies that timeline metadata can declare native-only regions for future playback coordination.
    @Test func nativeOnlyTimelineSegmentIsParsed() throws {
        let inspection = try inspectFixture(named: "native-only-timeline")

        #expect(inspection.protectedContentState == .trustedMetadataAllowed)
        #expect(inspection.metadata?.segments.count == 2)
        #expect(inspection.metadata?.segment(containing: 30)?.policy == .eligible)
        #expect(inspection.metadata?.segment(containing: 100)?.policy == .nativeOnly)
        #expect(inspection.metadata?.segment(containing: 100)?.reason == "credits-over-black")
    }

    /// Verifies that incomplete positive metadata does not authorize protected-content eligibility.
    @Test func incompleteEligibleMetadataFailsClosed() throws {
        let inspection = try inspectFixture(named: "incomplete-eligible-metadata")

        #expect(inspection.protectedContentState == .protectedWithoutTrustedMetadata)
        #expect(inspection.viewportState == .unknown)

        let decision = CaptionTheaterDecisionEngine().decision(for: inspection.eligibilitySnapshot())
        guard case let .uncertain(reason, evidence) = decision else {
            Issue.record("Expected incomplete metadata to be uncertain, got \(decision).")
            return
        }

        #expect(reason == .protectedContentRequiresTrustedMetadata)
        #expect(evidence.contains { $0.source == .providerSideQcMetadata && $0.polarity == .uncertain })
    }

    private func inspectFixture(named name: String) throws -> ProviderMetadataInspection {
        let document = try ProviderMetadataFixture.load(named: name)
        return ProviderMetadataInspector().inspect(document)
    }
}

/// Loads sanitized provider metadata fixtures from the unit test bundle.
private enum ProviderMetadataFixture {
    /// Returns the decoded provider metadata document for a resource name without its `.json` extension.
    static func load(named name: String) throws -> ProviderMetadataDocument {
        let bundle = Bundle(for: ProviderMetadataFixtureBundleToken.self)
        guard let fixtureURL = bundle.url(forResource: name, withExtension: "json") else {
            throw ProviderMetadataFixtureLoadingError.missingResource("\(name).json")
        }

        let data = try Data(contentsOf: fixtureURL)
        return try ProviderMetadataInspector().decode(data)
    }
}

/// Provides a stable Objective-C runtime anchor for locating the unit test bundle.
private final class ProviderMetadataFixtureBundleToken: NSObject {}

/// Errors that can occur before provider metadata fixture parsing begins.
private enum ProviderMetadataFixtureLoadingError: Error, Sendable {
    case missingResource(String)
}
