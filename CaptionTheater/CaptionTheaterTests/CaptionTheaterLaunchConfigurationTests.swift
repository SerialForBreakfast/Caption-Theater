//
//  CaptionTheaterLaunchConfigurationTests.swift
//  CaptionTheaterTests
//

import Foundation
import Testing
@testable import CaptionTheater

struct CaptionTheaterLaunchConfigurationTests {

    @Test func offlineShortcutSelectsBundledGeneratedWidescreenFixture() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: ["CaptionTheater", "--caption-theater-offline-hls"]
        )

        #expect(overrides.playbackDemoSource == .bundledGeneratedWidescreenFixture)
    }

    @Test func generatedShortcutSelectsBundledGeneratedWidescreenFixture() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: ["CaptionTheater", "--caption-theater-generated-hls"]
        )

        #expect(overrides.playbackDemoSource == .bundledGeneratedWidescreenFixture)
    }

    @Test func xcodeStylePlaybackDemoSourceArgumentIsResolved() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: [
                "CaptionTheater",
                "-CaptionTheater.playbackDemoSource",
                CaptionTheaterPlaybackDemoSource.bundledGeneratedWidescreenFixture.rawValue
            ]
        )

        #expect(overrides.playbackDemoSource == .bundledGeneratedWidescreenFixture)
    }

    @Test func longFormDebugHUDArgumentIsResolved() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: [
                "CaptionTheater",
                "--caption-theater-playback-debug-hud=yes"
            ]
        )

        #expect(overrides.playbackDebugHUD == true)
    }

    @Test func longFormLayoutBorderArgumentIsResolved() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: [
                "CaptionTheater",
                "--caption-theater-playback-layout-border=off"
            ]
        )

        #expect(overrides.playbackLayoutBorder == false)
    }

    @Test func longFormMacStartupAspectArgumentIsResolved() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: [
                "CaptionTheater",
                "--caption-theater-mac-startup-aspect=twentyOneByNine"
            ]
        )

        #expect(overrides.macStartupAspectPresetRawValue == "twentyOneByNine")
    }

    @Test func invalidPlaybackDemoSourceIsIgnored() {
        let overrides = CaptionTheaterLaunchConfiguration.resolvedOverrides(
            arguments: ["CaptionTheater", "--caption-theater-playback-demo-source=not-a-source"]
        )

        #expect(overrides.playbackDemoSource == nil)
    }

    @Test func generatedHLSMasterPlaylistIsBundled() {
        let url = CaptionTheaterPlaybackDemoSource.bundledGeneratedWidescreenFixture.playbackURL(bundle: .main)

        #expect(url?.lastPathComponent == "caption-theater-generated-master.m3u8")
    }
}
