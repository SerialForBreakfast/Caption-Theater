//
//  CaptionTheaterPlaybackFixture.swift
//  CaptionTheater
//
//  Bundled offline sample media for the playback shell (CT-0501).
//

import Foundation

/// Resolves packaged playback samples shipped inside the Caption Theater app bundle.
///
/// The generated HLS fixture is a project-owned 1920x800 video-only stream with timed WebVTT captions.
/// It is the preferred local/offline demo source because it avoids third-party redistribution questions.
///
/// For **networked** ultra-wide HLS with subtitles, see ``muxTearsOfSteelDemoMasterPlaylistURL`` and
/// ``CaptionTheaterPlaybackDemoSource`` (documented in ``Docs/Sources.md``).
enum CaptionTheaterPlaybackFixture {

    /// Resource name for ``sampleVideoURL()`` (without extension).
    static let sampleVideoResourceName = "CaptionTheaterSamplePlayback"

    /// File extension for ``sampleVideoURL()``.
    static let sampleVideoExtension = "mp4"

    /// Public Mux-hosted multivariant playlist (*Tears of Steel*) used as the default networked demo.
    ///
    /// **Privacy:** This is a documented third-party demo URL, not production customer media.
    /// Inner segment URLs are signed by Mux and may expire between playlist refreshes; `AVPlayer` reloads manifests normally.
    static let muxTearsOfSteelDemoMasterPlaylistURL = URL(string: "https://stream.mux.com/4XYzhPXzqArkFI8d1vDsScBLD69Gh1b2.m3u8")

    /// Repo-local generated HLS fixture: true ultra-wide video + English WebVTT subtitles, no audio.
    static let generatedWidescreenFixtureMasterPlaylistSubdirectory = "OfflineHLS/CaptionTheaterGeneratedWidescreenFixture"

    /// Master playlist filename for ``generatedWidescreenFixtureMasterPlaylistURL(bundle:)``.
    static let generatedWidescreenFixtureMasterPlaylistResourceName = "caption-theater-generated-master"

    /// Master playlist extension for ``generatedWidescreenFixtureMasterPlaylistURL(bundle:)``.
    static let generatedWidescreenFixtureMasterPlaylistExtension = "m3u8"

    /// Subtitle playlist subdirectory for the generated fixture.
    static let generatedWidescreenFixtureSubtitlePlaylistSubdirectory =
        generatedWidescreenFixtureMasterPlaylistSubdirectory + "/subtitles"

    /// Subtitle playlist filename for ``generatedWidescreenFixtureSubtitlePlaylistURL(bundle:)``.
    static let generatedWidescreenFixtureSubtitlePlaylistResourceName = "caption-theater-generated-english"

    /// Subtitle playlist extension for ``generatedWidescreenFixtureSubtitlePlaylistURL(bundle:)``.
    static let generatedWidescreenFixtureSubtitlePlaylistExtension = "m3u8"

    /// Repo-local five-minute HLS mock derived from the Mux Tears of Steel demo stream for private POC use.
    static let offlineHLSMockMasterPlaylistSubdirectory = "OfflineHLS/TearsOfSteelFiveMinuteMock"

    /// Master playlist filename for ``offlineHLSMockMasterPlaylistURL(bundle:)``.
    static let offlineHLSMockMasterPlaylistResourceName = "master"

    /// Master playlist extension for ``offlineHLSMockMasterPlaylistURL(bundle:)``.
    static let offlineHLSMockMasterPlaylistExtension = "m3u8"

    /// URL of the packaged MP4 used by ``tvOSPlaybackShellView``, when present in the bundle.
    static func sampleVideoURL(bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: sampleVideoResourceName, withExtension: sampleVideoExtension)
    }

    /// URL of the packaged generated HLS fixture master playlist, when present in the bundle.
    static func generatedWidescreenFixtureMasterPlaylistURL(bundle: Bundle = .main) -> URL? {
        if let preservedSubdirectoryURL = bundle.url(
            forResource: generatedWidescreenFixtureMasterPlaylistResourceName,
            withExtension: generatedWidescreenFixtureMasterPlaylistExtension,
            subdirectory: generatedWidescreenFixtureMasterPlaylistSubdirectory
        ) {
            return preservedSubdirectoryURL
        }

        return bundle.url(
            forResource: generatedWidescreenFixtureMasterPlaylistResourceName,
            withExtension: generatedWidescreenFixtureMasterPlaylistExtension
        )
    }

    /// URL of the packaged generated HLS fixture subtitle playlist, when present in the bundle.
    static func generatedWidescreenFixtureSubtitlePlaylistURL(bundle: Bundle = .main) -> URL? {
        if let preservedSubdirectoryURL = bundle.url(
            forResource: generatedWidescreenFixtureSubtitlePlaylistResourceName,
            withExtension: generatedWidescreenFixtureSubtitlePlaylistExtension,
            subdirectory: generatedWidescreenFixtureSubtitlePlaylistSubdirectory
        ) {
            return preservedSubdirectoryURL
        }

        return bundle.url(
            forResource: generatedWidescreenFixtureSubtitlePlaylistResourceName,
            withExtension: generatedWidescreenFixtureSubtitlePlaylistExtension
        )
    }

    /// URL of the packaged offline HLS mock master playlist, when present in the bundle.
    static func offlineHLSMockMasterPlaylistURL(bundle: Bundle = .main) -> URL? {
        if let preservedSubdirectoryURL = bundle.url(
            forResource: offlineHLSMockMasterPlaylistResourceName,
            withExtension: offlineHLSMockMasterPlaylistExtension,
            subdirectory: offlineHLSMockMasterPlaylistSubdirectory
        ) {
            return preservedSubdirectoryURL
        }

        return bundle.url(
            forResource: offlineHLSMockMasterPlaylistResourceName,
            withExtension: offlineHLSMockMasterPlaylistExtension
        )
    }
}
