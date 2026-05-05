import Foundation
import Testing
@testable import CaptionTheater

struct HLSManifestInspectorTests {

    /// Verifies that sidecar subtitle renditions and variant attributes are parsed from a multivariant playlist.
    @Test func sidecarSubtitleFixtureDeclaresTextSubtitleTransport() throws {
        let inspection = try inspectFixture(named: "sidecar-webvtt-master")

        #expect(inspection.isExtendedM3U)
        #expect(inspection.variants.count == 2)
        #expect(inspection.mediaRenditions.count == 2)
        #expect(inspection.declaredSubtitleTransports == [.sidecarTextSubtitles])
        #expect(inspection.variants.first?.resolution == HLSResolution(width: 1920, height: 1080))
        #expect(inspection.variants.first?.frameRate == 23.976)
        #expect(inspection.variants.first?.subtitleGroupID == "text-subtitles")
        #expect(!inspection.hasEncryptionSignal)
    }

    /// Verifies that embedded CEA-style closed captions are distinguished from sidecar text subtitles.
    @Test func embeddedClosedCaptionsFixtureDeclaresClosedCaptionTransport() throws {
        let inspection = try inspectFixture(named: "embedded-closed-captions-master")

        #expect(inspection.isExtendedM3U)
        #expect(inspection.declaredSubtitleTransports == [.embeddedClosedCaptions])
        #expect(inspection.mediaRenditions.first { $0.type == .closedCaptions }?.groupID == "embedded-cc")
        #expect(inspection.variants.first?.closedCaptionGroupID == "embedded-cc")
    }

    /// Verifies that date-range and discontinuity tags are preserved as revalidation evidence.
    @Test func adDateRangeFixtureReportsTimedMetadataAndDiscontinuity() throws {
        let inspection = try inspectFixture(named: "ad-daterange-discontinuity-media")

        #expect(inspection.isExtendedM3U)
        #expect(inspection.hasDateRangeMetadata)
        #expect(inspection.dateRanges.first?["ID"] == "fixture-ad-1")
        #expect(inspection.dateRanges.first?["CLASS"] == "com.captiontheater.fixture.ad")
        #expect(inspection.hasDiscontinuity)
        #expect(inspection.variants.isEmpty)
    }

    /// Verifies that encryption markers are detected without loading keys or media.
    @Test func encryptedFixtureReportsEncryptionSignal() throws {
        let inspection = try inspectFixture(named: "encrypted-session-key-master")

        #expect(inspection.isExtendedM3U)
        #expect(inspection.hasEncryptionSignal)
        #expect(inspection.encryptionMethods == ["SAMPLE-AES"])
        #expect(inspection.declaredSubtitleTransports.isEmpty)
    }

    /// Verifies that full-frame manifests with no text tracks do not invent subtitle support.
    @Test func noSubtitleFixtureReportsNoSubtitleTransport() throws {
        let inspection = try inspectFixture(named: "full-frame-no-subtitles-master")

        #expect(inspection.isExtendedM3U)
        #expect(inspection.variants.count == 1)
        #expect(inspection.declaredSubtitleTransports.isEmpty)
        #expect(inspection.variants.first?.closedCaptionGroupID == "NONE")
    }

    private func inspectFixture(named name: String) throws -> HLSManifestInspection {
        let manifestText = try HLSManifestFixture.load(named: name)
        return HLSManifestInspector().inspect(manifestText)
    }
}

/// Loads sanitized HLS fixture manifests from the unit test bundle.
private enum HLSManifestFixture {
    /// Returns the fixture manifest text for a resource name without its `.m3u8` extension.
    static func load(named name: String) throws -> String {
        let bundle = Bundle(for: HLSManifestFixtureBundleToken.self)
        guard let fixtureURL = bundle.url(forResource: name, withExtension: "m3u8") else {
            throw HLSManifestFixtureLoadingError.missingResource("\(name).m3u8")
        }

        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }
}

/// Provides a stable Objective-C runtime anchor for locating the unit test bundle.
private final class HLSManifestFixtureBundleToken: NSObject {}

/// Errors that can occur before manifest fixture parsing begins.
private enum HLSManifestFixtureLoadingError: Error, Sendable {
    case missingResource(String)
}
