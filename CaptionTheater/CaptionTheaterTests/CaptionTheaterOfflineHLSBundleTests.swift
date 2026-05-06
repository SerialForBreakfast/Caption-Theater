//
//  CaptionTheaterOfflineHLSBundleTests.swift
//  CaptionTheaterTests
//
//  Bundle-structure smoke checks for the bundled offline HLS mock (CT-0006).
//

import Foundation
import Testing

@testable import CaptionTheater

/// Validates that the five-minute *Tears of Steel* offline mock ships as a coherent tree under the host app bundle.
///
/// These tests run against ``Bundle.main`` because ``CaptionTheaterTests`` uses ``TEST_HOST`` and loads the app binary,
/// so packaged ``OfflineHLS`` resources resolve the same way they do at runtime.
struct CaptionTheaterOfflineHLSBundleTests {

    private let bundle = Bundle.main

    private func masterPlaylistURL() throws -> URL {
        try #require(CaptionTheaterPlaybackDemoSource.bundledOfflineHLSMock.playbackURL(bundle: bundle))
    }

    @Test func offlineHLSMockMasterPlaylistURLHasExpectedFilename() throws {
        let master = try masterPlaylistURL()

        #expect(master.lastPathComponent == CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistResourceName + "." + CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistExtension)
    }

    @Test func offlineHLSMockChildPlaylistsAndSegmentsExist() throws {
        let master = try masterPlaylistURL()
        let mockRoot = master.deletingLastPathComponent()
        let fileManager = FileManager.default

        let videoPlaylist = mockRoot.appendingPathComponent("video/video.m3u8", isDirectory: false)
        let subtitlePlaylist = mockRoot.appendingPathComponent("subtitles/english.m3u8", isDirectory: false)
        let sampleTransportSegment = mockRoot.appendingPathComponent("video/segments/seg000.ts", isDirectory: false)
        let sampleSubtitleSegment = mockRoot.appendingPathComponent("subtitles/segments/seg000.vtt", isDirectory: false)

        #expect(fileManager.fileExists(atPath: videoPlaylist.path))
        #expect(fileManager.fileExists(atPath: subtitlePlaylist.path))
        #expect(fileManager.fileExists(atPath: sampleTransportSegment.path))
        #expect(fileManager.fileExists(atPath: sampleSubtitleSegment.path))
    }

    @Test func offlineHLSMockMasterPlaylistDeclaresSubtitlesAndUltraWideResolution() throws {
        let master = try masterPlaylistURL()
        let text = try String(contentsOf: master, encoding: .utf8)

        #expect(text.contains("#EXT-X-MEDIA:"))
        #expect(text.contains("TYPE=SUBTITLES"))
        #expect(text.contains("RESOLUTION=1920x800"))
        #expect(text.contains("CLOSED-CAPTIONS=NONE"))
    }
}
