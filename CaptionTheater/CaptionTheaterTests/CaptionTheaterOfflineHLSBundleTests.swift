//
//  CaptionTheaterOfflineHLSBundleTests.swift
//  CaptionTheaterTests
//
//  Bundle-structure smoke checks for the bundled generated offline HLS fixture (CT-0006).
//

import Foundation
import Testing

@testable import CaptionTheater

/// Validates that the project-owned generated offline fixture ships as a coherent tree under the host app bundle.
///
/// These tests run against ``Bundle.main`` because ``CaptionTheaterTests`` uses ``TEST_HOST`` and loads the app binary,
/// so packaged ``OfflineHLS`` resources resolve the same way they do at runtime.
struct CaptionTheaterOfflineHLSBundleTests {

    private let bundle = Bundle.main

    private func masterPlaylistURL() throws -> URL {
        try #require(CaptionTheaterPlaybackDemoSource.bundledGeneratedWidescreenFixture.playbackURL(bundle: bundle))
    }

    @Test func generatedOfflineHLSMasterPlaylistURLHasExpectedFilename() throws {
        let master = try masterPlaylistURL()

        #expect(master.lastPathComponent == CaptionTheaterPlaybackFixture.generatedWidescreenFixtureMasterPlaylistResourceName + "." + CaptionTheaterPlaybackFixture.generatedWidescreenFixtureMasterPlaylistExtension)
    }

    @Test func generatedOfflineHLSChildPlaylistsAndSegmentsExist() throws {
        let master = try masterPlaylistURL()
        let mockRoot = master.deletingLastPathComponent()
        let fileManager = FileManager.default

        let videoPlaylist = mockRoot.appendingPathComponent("video/caption-theater-generated-video.m3u8", isDirectory: false)
        let subtitlePlaylist = mockRoot.appendingPathComponent("subtitles/caption-theater-generated-english.m3u8", isDirectory: false)
        let sampleTransportSegment = mockRoot.appendingPathComponent("video/segments/caption-theater-generated-video-000.ts", isDirectory: false)
        let sampleSubtitleSegment = mockRoot.appendingPathComponent("subtitles/segments/caption-theater-generated-subtitle-000.vtt", isDirectory: false)

        #expect(fileManager.fileExists(atPath: videoPlaylist.path))
        #expect(fileManager.fileExists(atPath: subtitlePlaylist.path))
        #expect(fileManager.fileExists(atPath: sampleTransportSegment.path))
        #expect(fileManager.fileExists(atPath: sampleSubtitleSegment.path))
    }

    @Test func generatedOfflineHLSMasterPlaylistDeclaresVideoOnlySubtitlesAndUltraWideResolution() throws {
        let master = try masterPlaylistURL()
        let text = try String(contentsOf: master, encoding: .utf8)

        #expect(text.contains("#EXT-X-MEDIA:"))
        #expect(text.contains("TYPE=SUBTITLES"))
        #expect(text.contains("RESOLUTION=1920x800"))
        #expect(text.contains("CLOSED-CAPTIONS=NONE"))
        #expect(text.contains("CODECS=\"avc1."))
        #expect(!text.contains("mp4a"))
    }

    @Test func generatedOfflineHLSProvenanceDocumentsNoAudioV1() throws {
        let master = try masterPlaylistURL()
        let provenance = master
            .deletingLastPathComponent()
            .appendingPathComponent("CAPTION_THEATER_GENERATED_PROVENANCE.md", isDirectory: false)
        let text = try String(contentsOf: provenance, encoding: .utf8)

        #expect(text.contains("No audio in v1."))
    }
}
