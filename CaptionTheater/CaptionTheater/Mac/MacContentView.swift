//
//  MacContentView.swift
//  CaptionTheater
//
//  Root view for the native macOS target.
//

#if os(macOS)
import SwiftUI

struct MacContentView: View {

    @AppStorage(CaptionTheaterLaunchConfiguration.playbackDemoSourceStorageKey)
    private var playbackDemoSourceRawValue = CaptionTheaterPlaybackDemoSource.bundledGeneratedWidescreenFixture.rawValue

    @AppStorage(CaptionTheaterLaunchConfiguration.macStartupAspectPresetStorageKey)
    private var startupAspectPresetRawValue = MacWindowAspectPreset.freeform.rawValue

    @State private var didApplyStartupAspectPreset = false

    private var playbackDemoSource: CaptionTheaterPlaybackDemoSource {
        CaptionTheaterPlaybackDemoSource(rawValue: playbackDemoSourceRawValue) ?? .bundledGeneratedWidescreenFixture
    }

    init() {
        CaptionTheaterLaunchConfiguration.apply()
    }

    var body: some View {
        MacPlaybackShellView(
            demoSource: playbackDemoSource,
            playbackURL: playbackDemoSource.playbackURL()
        )
        .id(playbackDemoSourceRawValue)
        .frame(minWidth: 960, minHeight: 540)
        .onAppear {
            applyStartupAspectPresetIfNeeded()
        }
    }

    private func applyStartupAspectPresetIfNeeded() {
        guard !didApplyStartupAspectPreset,
              let preset = MacWindowAspectPreset(rawValue: startupAspectPresetRawValue),
              preset != .freeform
        else {
            return
        }

        didApplyStartupAspectPreset = true
        DispatchQueue.main.async {
            MacWindowAspectController.apply(
                preset,
                sourceAspect: MacPlaybackStateStore.shared.sourceAspectForWindowPreset
            )
        }
    }
}
#endif
