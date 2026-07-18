//
//  CaptionTheaterPlaybackDemoSource.swift
//  CaptionTheater
//
//  Chooses bundled vs. networked demo media for the tvOS playback shell (CT-0501).
//

import Foundation

/// Selectable demo playback origins documented in ``Docs/Sources.md``.
///
/// The generated fixture is the preferred local/offline source for demos and tests because the project owns
/// the visual media and timed WebVTT captions. The **Mux** URL remains useful as a networked comparison source.
enum CaptionTheaterPlaybackDemoSource: String, CaseIterable, Identifiable {

    /// Bundled synthetic clip from ``CaptionTheaterPlaybackFixture`` (offline; typically ~16:9 presentation).
    case bundledSyntheticSample

    /// Bundled project-owned generated HLS fixture: true ultra-wide video + English WebVTT subtitles, no audio.
    case bundledGeneratedWidescreenFixture

    /// Bundled five-minute local HLS mock: true ultra-wide video + English WebVTT subtitles, private POC only.
    case bundledOfflineHLSMock

    /// Public Mux VOD stream: ultra-wide ladder + sidecar subtitles (see ``Docs/Sources.md`` candidate #1).
    case muxTearsOfSteelHLS

    var id: String { rawValue }

    /// Short label for settings-style pickers.
    var menuTitle: String {
        switch self {
        case .bundledSyntheticSample:
            return "Bundled synthetic sample"
        case .bundledGeneratedWidescreenFixture:
            return "Generated widescreen fixture (UW + captions)"
        case .bundledOfflineHLSMock:
            return "Legacy offline HLS mock (private POC)"
        case .muxTearsOfSteelHLS:
            return "Mux: Tears of Steel (HLS, UW + subs)"
        }
    }

    /// User-facing missing-media guidance for sources that resolve from the app bundle.
    var missingPlaybackGuidance: String {
        switch self {
        case .bundledSyntheticSample:
            return "Add \(CaptionTheaterPlaybackFixture.sampleVideoResourceName).\(CaptionTheaterPlaybackFixture.sampleVideoExtension) to the app target Media folder."
        case .bundledGeneratedWidescreenFixture:
            return "Add \(CaptionTheaterPlaybackFixture.generatedWidescreenFixtureMasterPlaylistSubdirectory)/\(CaptionTheaterPlaybackFixture.generatedWidescreenFixtureMasterPlaylistResourceName).\(CaptionTheaterPlaybackFixture.generatedWidescreenFixtureMasterPlaylistExtension) to the app target Media folder."
        case .bundledOfflineHLSMock:
            return "Add \(CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistSubdirectory)/\(CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistResourceName).\(CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistExtension) to the app target Media folder."
        case .muxTearsOfSteelHLS:
            return "The Mux demo URL failed to resolve. Change `CaptionTheater.playbackDemoSource` in User Defaults or launch arguments."
        }
    }

    /// Resolves the ``URL`` used by ``AVPlayer`` for this source; nil when the bundled sample is missing from the target.
    func playbackURL(bundle: Bundle = .main) -> URL? {
        switch self {
        case .bundledSyntheticSample:
            CaptionTheaterPlaybackFixture.sampleVideoURL(bundle: bundle)
        case .bundledGeneratedWidescreenFixture:
            CaptionTheaterPlaybackFixture.generatedWidescreenFixtureMasterPlaylistURL(bundle: bundle)
        case .bundledOfflineHLSMock:
            CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistURL(bundle: bundle)
        case .muxTearsOfSteelHLS:
            CaptionTheaterPlaybackFixture.muxTearsOfSteelDemoMasterPlaylistURL
        }
    }
}
