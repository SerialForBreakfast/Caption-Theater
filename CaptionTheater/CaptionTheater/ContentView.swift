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

    private var playbackDemoSource: CaptionTheaterPlaybackDemoSource {
        CaptionTheaterPlaybackDemoSource(rawValue: playbackDemoSourceRawValue) ?? .muxTearsOfSteelHLS
    }

    init() {
        CaptionTheaterLaunchConfiguration.apply()
    }

    var body: some View {
        NavigationStack {
            tvOSPlaybackShellView(
                demoSource: playbackDemoSource,
                playbackURL: playbackDemoSource.playbackURL()
            )
            .id(playbackDemoSourceRawValue)
        }
    }
}

#Preview {
    ContentView()
}
