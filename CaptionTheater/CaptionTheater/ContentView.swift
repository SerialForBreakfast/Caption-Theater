//
//  ContentView.swift
//  CaptionTheater
//
//  Created by Joseph McCraw on 5/5/26.
//

import SwiftUI

/// Root scene: fullscreen playback only (engineering HUD via `CaptionTheater.playbackDebugHUD` User Defaults).
///
/// The eligibility inspector lives in ``CaptionTheaterDebugDecisionInspectorView`` for future reattachment;
/// demo media selection uses `CaptionTheater.playbackDemoSource` (same keys as the former Debug tab).
struct ContentView: View {

    /// Persisted demo media choice; changing it recreates the shell via `.id(...)`.
    @AppStorage(CaptionTheaterLaunchConfiguration.playbackDemoSourceStorageKey)
    private var playbackDemoSourceRawValue = CaptionTheaterPlaybackDemoSource.muxTearsOfSteelHLS.rawValue

    @AppStorage(CaptionTheaterLaunchConfiguration.playbackDebugHUDStorageKey)
    private var playbackDebugHUD = false

    @AppStorage(CaptionTheaterLaunchConfiguration.showFeatureTogglesStorageKey)
    private var showFeatureToggles = false

    @AppStorage(CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey)
    private var captionTextSizeRaw = CaptionTheaterCaptionTextPreferences.defaultTextSizeRawValue

    private var playbackDemoSource: CaptionTheaterPlaybackDemoSource {
        CaptionTheaterPlaybackDemoSource(rawValue: playbackDemoSourceRawValue) ?? .muxTearsOfSteelHLS
    }

    init() {
        CaptionTheaterLaunchConfiguration.apply()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                tvOSPlaybackShellView(
                    demoSource: playbackDemoSource,
                    playbackURL: playbackDemoSource.playbackURL()
                )
                .id(playbackDemoSourceRawValue)

                featureToggleButton
            }
        }
        .sheet(isPresented: $showFeatureToggles) {
            CaptionTheaterFeatureTogglesView(
                playbackDemoSourceRawValue: $playbackDemoSourceRawValue,
                playbackDebugHUD: $playbackDebugHUD,
                captionTextSizeRaw: $captionTextSizeRaw
            )
        }
    }

    private var featureToggleButton: some View {
        Button {
            showFeatureToggles = true
        } label: {
            Label("Feature Toggles", systemImage: "slider.horizontal.3")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .padding(32)
        .accessibilityIdentifier("CaptionTheaterFeatureTogglesButton")
    }
}

#Preview {
    ContentView()
}

private struct CaptionTheaterFeatureTogglesView: View {

    @Binding var playbackDemoSourceRawValue: String
    @Binding var playbackDebugHUD: Bool
    @Binding var captionTextSizeRaw: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Picker("Demo media", selection: $playbackDemoSourceRawValue) {
                        ForEach(CaptionTheaterPlaybackDemoSource.allCases) { source in
                            Text(source.menuTitle).tag(source.rawValue)
                        }
                    }

                    Toggle("Playback debug HUD", isOn: $playbackDebugHUD)
                }

                Section("Captions") {
                    Picker("Text size", selection: $captionTextSizeRaw) {
                        ForEach(CaptionTheaterCaptionTextSizePreset.allCases) { preset in
                            Text(preset.menuTitle).tag(preset.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Feature Toggles")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
