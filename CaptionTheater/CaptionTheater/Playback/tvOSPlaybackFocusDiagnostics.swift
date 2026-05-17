//
//  tvOSPlaybackFocusDiagnostics.swift
//  CaptionTheater
//
//  Opt-in style: attach ``View/logTVOSFocusTransitions(_:)`` to individual controls to correlate
//  Siri Remote focus with ``EnvironmentValues/isFocused``.
//

import SwiftUI

/// Logs ``EnvironmentValues/isFocused`` transitions for a subtree (tvOS).
private struct TVOSPlaybackFocusTransitionLogger: ViewModifier {

    let label: String

    @Environment(\.isFocused)
    private var isFocused

    func body(content: Content) -> some View {
        content
            .onChange(of: isFocused) { _, newValue in
                CaptionTheaterPlaybackLogger.playbackFocus("\(label) Environment.isFocused=\(newValue)")
            }
    }
}

extension View {

    /// Records focus enter/exit for this view in the `PlaybackFocus` log category.
    func logTVOSFocusTransitions(_ label: String) -> some View {
        modifier(TVOSPlaybackFocusTransitionLogger(label: label))
    }
}
