//
//  CaptionTheaterWebVTTFixtureAdapterTests.swift
//  CaptionTheaterTests
//

import Foundation
import Testing

@testable import CaptionTheater

struct CaptionTheaterWebVTTFixtureAdapterTests {

    @Test func generatedFixturePlaylistConvertsDeterministically() throws {
        let root = try generatedFixtureRoot()
        let playlist = root.appendingPathComponent("subtitles/caption-theater-generated-english.m3u8", isDirectory: false)
        let cues = try CaptionTheaterWebVTTFixtureAdapter.cues(fromSegmentPlaylistURL: playlist)

        #expect(cues.count == 10)
        #expect(cues.first?.id == "CT-001")
        #expect(cues.first?.startSeconds == 1.0)
        #expect(cues.first?.endSeconds == 5.0)
        #expect(cues.first?.text == "Caption Theater generated fixture: true 1920 by 800 widescreen video.")
        #expect(cues.map(\.id) == (1...10).map { String(format: "CT-%03d", $0) })
    }

    @Test func parserSkipsInvalidTimestampsAndEmptyText() {
        let text = """
        WEBVTT

        VALID
        00:00:01.000 --> 00:00:02.000
        Visible text

        BAD
        no timestamp
        This should not parse.

        EMPTY
        00:00:03.000 --> 00:00:04.000

        BACKWARDS
        00:00:05.000 --> 00:00:04.000
        Time is invalid.
        """

        let cues = CaptionTheaterWebVTTFixtureAdapter.cues(fromWebVTTText: text)

        #expect(cues.count == 1)
        #expect(cues[0].id == "VALID")
        #expect(cues[0].text == "Visible text")
    }

    @Test func parserPreservesMultilineTextAndStripsBasicMarkup() {
        let text = """
        WEBVTT

        MULTI
        00:00:01.000 --> 00:00:04.000
        <v ALEX>First line
        <i>Second line</i>
        """

        let cues = CaptionTheaterWebVTTFixtureAdapter.cues(fromWebVTTText: text)

        #expect(cues.count == 1)
        #expect(cues[0].text == "First line\nSecond line")
    }

    private func generatedFixtureRoot() throws -> URL {
        let master = try #require(
            CaptionTheaterPlaybackDemoSource.bundledGeneratedWidescreenFixture.playbackURL(bundle: .main)
        )
        return master.deletingLastPathComponent()
    }
}
