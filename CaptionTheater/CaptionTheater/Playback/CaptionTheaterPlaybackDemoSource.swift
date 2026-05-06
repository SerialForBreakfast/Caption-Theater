//
//  CaptionTheaterPlaybackDemoSource.swift
//  CaptionTheater
//
//  Chooses bundled vs. networked demo media for the tvOS playback shell (CT-0501).
//

import Foundation

/// Selectable demo playback origins documented in ``Docs/Sources.md``.
///
/// The **Mux** URL is a public HLS test asset (*Tears of Steel*) with **true ultra-wide variants**
/// (for example `1920×800`) and declared WebVTT subtitle renditions—ideal for exercising non-zero
/// Caption Theater bands on-device. Requires network access and depends on Mux continuing to host the asset.
enum CaptionTheaterPlaybackDemoSource: String, CaseIterable, Identifiable {

    /// Bundled synthetic clip from ``CaptionTheaterPlaybackFixture`` (offline; typically ~16:9 presentation).
    case bundledSyntheticSample

    /// Bundled five-minute local HLS mock: true ultra-wide video + English WebVTT subtitles.
    case bundledOfflineHLSMock

    /// Public Mux VOD stream: ultra-wide ladder + sidecar subtitles (see ``Docs/Sources.md`` candidate #1).
    case muxTearsOfSteelHLS

    var id: String { rawValue }

    /// Short label for settings-style pickers.
    var menuTitle: String {
        switch self {
        case .bundledSyntheticSample:
            return "Bundled synthetic sample"
        case .bundledOfflineHLSMock:
            return "Offline HLS mock (5 min, UW + subs)"
        case .muxTearsOfSteelHLS:
            return "Mux: Tears of Steel (HLS, UW + subs)"
        }
    }

    /// User-facing missing-media guidance for sources that resolve from the app bundle.
    var missingPlaybackGuidance: String {
        switch self {
        case .bundledSyntheticSample:
            return "Add \(CaptionTheaterPlaybackFixture.sampleVideoResourceName).\(CaptionTheaterPlaybackFixture.sampleVideoExtension) to the app target Media folder."
        case .bundledOfflineHLSMock:
            return "Add \(CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistSubdirectory)/\(CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistResourceName).\(CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistExtension) to the app target Media folder."
        case .muxTearsOfSteelHLS:
            return "The Mux demo URL failed to resolve. Change `CaptionTheater.playbackDemoSource` in Feature Toggles or launch arguments."
        }
    }

    /// Resolves the ``URL`` used by ``AVPlayer`` for this source; nil when the bundled sample is missing from the target.
    func playbackURL(bundle: Bundle = .main) -> URL? {
        switch self {
        case .bundledSyntheticSample:
            CaptionTheaterPlaybackFixture.sampleVideoURL(bundle: bundle)
        case .bundledOfflineHLSMock:
            CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistURL(bundle: bundle)
        case .muxTearsOfSteelHLS:
            CaptionTheaterPlaybackFixture.muxTearsOfSteelDemoMasterPlaylistURL
        }
    }
}
