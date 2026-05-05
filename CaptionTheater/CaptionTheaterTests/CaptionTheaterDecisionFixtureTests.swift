import Foundation
import Testing
@testable import CaptionTheater

struct CaptionTheaterDecisionFixtureTests {

    /// Verifies that documented decision fixtures stay aligned with `CaptionTheaterDecisionEngine`.
    @Test func decisionFixturesMatchExpectedOutcomes() throws {
        let fixtures = try DecisionScenarioFixture.loadAll()
        #expect(!fixtures.isEmpty)

        let engine = CaptionTheaterDecisionEngine()

        for fixture in fixtures {
            let decision = engine.decision(for: fixture.snapshot)

            switch (decision, fixture.expected.outcome) {
            case (.eligible, .eligible):
                #expect(fixture.expected.reason == nil)
            case let (.ineligible(reason, _), .ineligible):
                #expect(fixture.expected.reason == .ineligible(reason))
            case let (.uncertain(reason, _), .uncertain):
                #expect(fixture.expected.reason == .uncertain(reason))
            default:
                Issue.record("Fixture \(fixture.id) expected \(fixture.expected), got \(decision).")
            }
        }
    }
}

/// A sanitized JSON scenario that can be decoded into a decision-engine input snapshot.
private struct DecisionScenarioFixture: Decodable, Sendable {
    let id: String
    let summary: String
    let snapshot: CaptionTheaterEligibilitySnapshot
    let expected: ExpectedDecision

    /// Loads all decision scenarios from the test bundle's copied fixture resource.
    static func loadAll() throws -> [Self] {
        let bundle = Bundle(for: DecisionFixtureBundleToken.self)
        guard let fixtureURL = bundle.url(forResource: "decision-scenarios", withExtension: "json") else {
            throw DecisionFixtureLoadingError.missingResource("decision-scenarios.json")
        }

        let data = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        return try decoder.decode([Self].self, from: data)
    }
}

/// Provides a stable Objective-C runtime anchor for locating the unit test bundle.
private final class DecisionFixtureBundleToken: NSObject {}

/// Errors that can occur before fixture JSON decoding begins.
private enum DecisionFixtureLoadingError: Error, Sendable {
    case missingResource(String)
}

/// The expected result summary stored beside each fixture snapshot.
private struct ExpectedDecision: Decodable, Equatable, Sendable {
    let outcome: Outcome
    let reason: ExpectedReason?
}

/// The top-level decision outcome expected for a fixture snapshot.
private enum Outcome: String, Decodable, Sendable {
    case eligible
    case ineligible
    case uncertain
}

/// The typed reason expected for ineligible or uncertain fixture decisions.
private enum ExpectedReason: Equatable, Sendable {
    case ineligible(CaptionTheaterIneligibilityReason)
    case uncertain(CaptionTheaterUncertaintyReason)
}

extension ExpectedReason: Decodable {
    /// Decodes a reason from either known ineligibility reasons or known uncertainty reasons.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let reason = try container.decode(String.self)

        if let ineligibilityReason = CaptionTheaterIneligibilityReason(rawFixtureValue: reason) {
            self = .ineligible(ineligibilityReason)
            return
        }

        if let uncertaintyReason = CaptionTheaterUncertaintyReason(rawFixtureValue: reason) {
            self = .uncertain(uncertaintyReason)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unknown Caption Theater fixture reason: \(reason)"
        )
    }
}

private extension CaptionTheaterIneligibilityReason {
    /// Maps JSON fixture reason strings to ineligibility reasons without exposing raw values in production models.
    init?(rawFixtureValue: String) {
        switch rawFixtureValue {
        case "disabledByUser":
            self = .disabledByUser
        case "adPlaybackActive":
            self = .adPlaybackActive
        case "promoPlaybackActive":
            self = .promoPlaybackActive
        case "noSubtitleTrackSelected":
            self = .noSubtitleTrackSelected
        case "unsupportedSubtitleFormat":
            self = .unsupportedSubtitleFormat
        case "noUsefulInactiveRegion":
            self = .noUsefulInactiveRegion
        case "unsafeViewportRegion":
            self = .unsafeViewportRegion
        case "variableAspectRatio":
            self = .variableAspectRatio
        default:
            return nil
        }
    }
}

private extension CaptionTheaterUncertaintyReason {
    /// Maps JSON fixture reason strings to uncertainty reasons without exposing raw values in production models.
    init?(rawFixtureValue: String) {
        switch rawFixtureValue {
        case "unknownAdPlaybackState":
            self = .unknownAdPlaybackState
        case "unknownSubtitleFormat":
            self = .unknownSubtitleFormat
        case "unknownViewportSafety":
            self = .unknownViewportSafety
        case "protectedContentRequiresTrustedMetadata":
            self = .protectedContentRequiresTrustedMetadata
        case "unknownProtectedContentState":
            self = .unknownProtectedContentState
        default:
            return nil
        }
    }
}
