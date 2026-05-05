//
//  CaptionTheaterPlaybackEvidenceAssemblerTests.swift
//  CaptionTheaterTests
//

import Foundation
import Testing
@testable import CaptionTheater

struct CaptionTheaterPlaybackEvidenceAssemblerTests {

    private let assembler = CaptionTheaterPlaybackEvidenceAssembler()

    /// Confirms manifest encryption fails closed until trusted provider metadata arrives.
    @Test func encryptedManifestWithoutProviderIsUncertain() throws {
        let manifest = try loadManifest(named: "encrypted-session-key-master")
        let subtitle = try classifySubtitle(named: "sidecar-webvtt-dialogue")

        let snapshot = assembler.assemble(
            isEnabledByUser: true,
            adPlaybackState: .content,
            manifest: manifest,
            provider: nil,
            subtitle: subtitle
        )

        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        guard case let .uncertain(reason, _) = decision else {
            Issue.record("Expected DRM uncertainty without provider metadata, got \(decision).")
            return
        }

        #expect(reason == .protectedContentRequiresTrustedMetadata)
    }

    /// Confirms trusted provider QC metadata can authorize eligibility despite encrypted manifest markers.
    @Test func encryptedManifestWithTrustedProviderCanBeEligible() throws {
        let manifest = try loadManifest(named: "encrypted-session-key-master")
        let provider = try inspectProvider(named: "trusted-eligible-letterbox")
        let subtitle = try classifySubtitle(named: "sidecar-webvtt-dialogue")

        let snapshot = assembler.assemble(
            isEnabledByUser: true,
            adPlaybackState: .content,
            manifest: manifest,
            provider: provider,
            subtitle: subtitle
        )

        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        guard case .eligible = decision else {
            Issue.record("Expected encrypted manifest + trusted QC metadata to pass DRM gates, got \(decision).")
            return
        }
    }

    /// Confirms full-frame manifest hints remove inactive regions after subtitles succeed.
    @Test func fullFrameManifestHintRemainsNativeForInactiveRegionGate() throws {
        let manifest = try loadManifest(named: "full-frame-no-subtitles-master")
        let subtitle = try classifySubtitle(named: "sidecar-webvtt-dialogue")

        let snapshot = assembler.assemble(
            isEnabledByUser: true,
            adPlaybackState: .content,
            manifest: manifest,
            provider: nil,
            subtitle: subtitle
        )

        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        guard case let .ineligible(reason, _) = decision else {
            Issue.record("Expected full-frame hint to block Caption Theater, got \(decision).")
            return
        }

        #expect(reason == .noUsefulInactiveRegion)
    }

    /// Confirms burned-in subtitle metadata rejects Caption Theater before viewport reasoning matters.
    @Test func burnedInSubtitleOverridesTrustedProviderLetterbox() throws {
        let manifest = try loadManifest(named: "sidecar-webvtt-master")
        let provider = try inspectProvider(named: "trusted-eligible-letterbox")
        let subtitle = try classifySubtitle(named: "burned-in-subtitles")

        let snapshot = assembler.assemble(
            isEnabledByUser: true,
            adPlaybackState: .content,
            manifest: manifest,
            provider: provider,
            subtitle: subtitle
        )

        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        guard case let .ineligible(reason, _) = decision else {
            Issue.record("Expected burned-in subtitles to force native playback, got \(decision).")
            return
        }

        #expect(reason == .unsupportedSubtitleFormat)
    }

    /// Confirms provider variable-aspect warnings map through the assembler into viewport decisions.
    @Test func variableAspectProviderWarningStaysNative() throws {
        let manifest = try loadManifest(named: "sidecar-webvtt-master")
        let provider = try inspectProvider(named: "variable-aspect-warning")
        let subtitle = try classifySubtitle(named: "sidecar-webvtt-dialogue")

        let snapshot = assembler.assemble(
            isEnabledByUser: true,
            adPlaybackState: .content,
            manifest: manifest,
            provider: provider,
            subtitle: subtitle
        )

        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        guard case let .ineligible(reason, _) = decision else {
            Issue.record("Expected variable aspect viewport classification to fail closed, got \(decision).")
            return
        }

        #expect(reason == .variableAspectRatio)
    }

    /// Ensures packaged playback scenarios resolve resources shipped beside the sample MP4.
    @Test func bundledPlaybackScenarioPackLoadsFromMainBundle() throws {
        let pack = try CaptionTheaterPlaybackScenarioKind.eligibleUltraWideLetterbox.loadPack(bundle: Bundle.main)

        #expect(pack.manifest != nil)
        #expect(pack.provider != nil)
        #expect(pack.subtitle != nil)
        #expect(pack.manifest?.hasEncryptionSignal == false)

        let snapshot = assembler.assemble(
            isEnabledByUser: true,
            adPlaybackState: .content,
            manifest: pack.manifest,
            provider: pack.provider,
            subtitle: pack.subtitle
        )

        let decision = CaptionTheaterDecisionEngine().decision(for: snapshot)
        guard case .eligible = decision else {
            Issue.record("Expected bundled scenario pack to reach eligibility when opted in, got \(decision).")
            return
        }
    }

    private func loadManifest(named name: String) throws -> HLSManifestInspection {
        let text = try AssemblerTestsHLSManifestFixture.load(named: name)
        return HLSManifestInspector().inspect(text)
    }

    private func inspectProvider(named name: String) throws -> ProviderMetadataInspection {
        let document = try AssemblerTestsProviderMetadataFixture.load(named: name)
        return ProviderMetadataInspector().inspect(document)
    }

    private func classifySubtitle(named name: String) throws -> SubtitleMetadataClassification {
        let document = try AssemblerTestsSubtitleMetadataFixture.load(named: name)
        return SubtitleMetadataClassifier().classify(document)
    }
}

private enum AssemblerTestsProviderMetadataFixture {
    static func load(named name: String) throws -> ProviderMetadataDocument {
        let bundle = Bundle(for: AssemblerTestsProviderMetadataFixtureBundleToken.self)
        guard let fixtureURL = bundle.url(forResource: name, withExtension: "json") else {
            throw AssemblerTestsFixtureError.missingResource("\(name).json")
        }

        let data = try Data(contentsOf: fixtureURL)
        return try ProviderMetadataInspector().decode(data)
    }
}

private final class AssemblerTestsProviderMetadataFixtureBundleToken: NSObject {}

private enum AssemblerTestsSubtitleMetadataFixture {
    static func load(named name: String) throws -> SubtitleMetadataDocument {
        let bundle = Bundle(for: AssemblerTestsSubtitleMetadataFixtureBundleToken.self)
        guard let fixtureURL = bundle.url(forResource: name, withExtension: "json") else {
            throw AssemblerTestsFixtureError.missingResource("\(name).json")
        }

        let data = try Data(contentsOf: fixtureURL)
        return try SubtitleMetadataClassifier().decode(data)
    }
}

private final class AssemblerTestsSubtitleMetadataFixtureBundleToken: NSObject {}

private enum AssemblerTestsHLSManifestFixture {
    static func load(named name: String) throws -> String {
        let bundle = Bundle(for: AssemblerTestsHLSManifestFixtureBundleToken.self)
        guard let fixtureURL = bundle.url(forResource: name, withExtension: "m3u8") else {
            throw AssemblerTestsFixtureError.missingResource("\(name).m3u8")
        }

        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }
}

private final class AssemblerTestsHLSManifestFixtureBundleToken: NSObject {}

private enum AssemblerTestsFixtureError: Error {
    case missingResource(String)
}
