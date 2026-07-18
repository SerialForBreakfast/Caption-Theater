//
//  CaptionTheaterMacApp.swift
//  CaptionTheater
//
//  Native macOS app entry point.
//

#if os(macOS)
import SwiftUI

@main
struct CaptionTheaterMacApp: App {

    @AppStorage(CaptionTheaterLaunchConfiguration.playbackDebugHUDStorageKey)
    private var playbackDebugHUD = false

    @AppStorage(CaptionTheaterLaunchConfiguration.playbackLayoutBorderStorageKey)
    private var playbackLayoutBorder = true

    @AppStorage(CaptionTheaterLaunchConfiguration.playbackDemoSourceStorageKey)
    private var playbackDemoSourceRawValue = CaptionTheaterPlaybackDemoSource.bundledGeneratedWidescreenFixture.rawValue

    @AppStorage(CaptionTheaterLaunchConfiguration.macStartupAspectPresetStorageKey)
    private var startupAspectPresetRawValue = MacWindowAspectPreset.freeform.rawValue

    var body: some Scene {
        WindowGroup {
            MacContentView()
        }
        .defaultSize(width: 1280, height: 720)
        .commands {
            CommandGroup(after: .windowSize) {
                Menu("Aspect Ratio") {
                    ForEach(MacWindowAspectPreset.allCases) { preset in
                        Button(preset.menuTitle) {
                            MacWindowAspectController.apply(
                                preset,
                                sourceAspect: MacPlaybackStateStore.shared.sourceAspectForWindowPreset
                            )
                        }
                    }
                }
            }

            CommandMenu("Caption Theater") {
                Button("Play/Pause") {
                    MacPlaybackStateStore.shared.activePlaybackModel?.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Restart Demo") {
                    MacPlaybackStateStore.shared.activePlaybackModel?.restartPlayback()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Menu("Demo Source") {
                    ForEach(CaptionTheaterPlaybackDemoSource.allCases) { source in
                        Button(source.menuTitle) {
                            playbackDemoSourceRawValue = source.rawValue
                        }
                    }
                }

                Menu("Startup Aspect Preset") {
                    ForEach(MacWindowAspectPreset.allCases) { preset in
                        Button(preset.menuTitle) {
                            startupAspectPresetRawValue = preset.rawValue
                        }
                    }
                }

                Divider()

                Toggle("Debug HUD", isOn: $playbackDebugHUD)
                    .keyboardShortcut("d", modifiers: [.command, .shift])

                Toggle("Layout Border", isOn: $playbackLayoutBorder)
                    .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }
    }
}
#endif
