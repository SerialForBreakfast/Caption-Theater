//
//  CaptionTheaterLaunchConfigurationTests.swift
//  CaptionTheaterTests
//

import Testing
@testable import CaptionTheater

struct CaptionTheaterLaunchConfigurationTests {

    @Test func offlineShortcutSelectsBundledOfflineHLSMock() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: ["CaptionTheater", "--caption-theater-offline-hls"]
        )

        #expect(overrides.playbackDemoSource == .bundledOfflineHLSMock)
    }

    @Test func xcodeStylePlaybackDemoSourceArgumentIsResolved() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: [
                "CaptionTheater",
                "-CaptionTheater.playbackDemoSource",
                CaptionTheaterPlaybackDemoSource.bundledOfflineHLSMock.rawValue
            ]
        )

        #expect(overrides.playbackDemoSource == .bundledOfflineHLSMock)
    }

    @Test func longFormFeatureToggleArgumentIsResolved() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: [
                "CaptionTheater",
                "--caption-theater-show-feature-toggles",
                "--caption-theater-playback-debug-hud=yes"
            ]
        )

        #expect(overrides.showFeatureToggles == true)
        #expect(overrides.playbackDebugHUD == true)
    }

    @Test func invalidPlaybackDemoSourceIsIgnored() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: ["CaptionTheater", "--caption-theater-playback-demo-source=not-a-source"]
        )

        #expect(overrides.playbackDemoSource == nil)
    }

    @Test func offlineHLSMockMasterPlaylistIsBundled() {
        let url = CaptionTheaterPlaybackDemoSource.bundledOfflineHLSMock.playbackURL(bundle: .main)

        #expect(url?.lastPathComponent == "master.m3u8")
    }
}
