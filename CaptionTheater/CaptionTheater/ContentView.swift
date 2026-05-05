//
//  ContentView.swift
//  CaptionTheater
//
//  Created by Joseph McCraw on 5/5/26.
//

import SwiftUI

/// Primary shell: playback showcase plus engineering-only debug tooling.
struct ContentView: View {

    private enum Tab: Hashable {
        case home
        case debug
    }

    @State private var selectedTab: Tab = .home
    /// Cleared when leaving Debug so returning to the tab always lands on the baseline scenario list.
    @State private var debugNavigationPath: [String] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                tvOSPlaybackShellView(fixtureURL: CaptionTheaterPlaybackFixture.sampleVideoURL())
            }
            .tabItem {
                Label("Playback", systemImage: "play.rectangle.fill")
            }
            .tag(Tab.home)

            CaptionTheaterDebugDecisionInspectorView(navigationPath: $debugNavigationPath)
                .tabItem {
                    Label("Debug", systemImage: "ladybug.fill")
                }
                .tag(Tab.debug)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != .debug {
                debugNavigationPath.removeAll()
            }
        }
    }
}

#Preview {
    ContentView()
}
