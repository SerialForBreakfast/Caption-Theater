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

    /// Rounded-rectangle outline in **white** (4 pt) when ``EnvironmentValues/isFocused`` is true.
    func tvOSHighContrastFocusBorder(cornerRadius: CGFloat = 12) -> some View {
        modifier(TVOSHighContrastFocusRectBorder(cornerRadius: cornerRadius))
    }

    /// Circular outline in **white** (4 pt) when focused (collapsed transport affordance).
    func tvOSHighContrastFocusCircleBorder() -> some View {
        modifier(TVOSHighContrastFocusCircleBorderModifier())
    }
}

// MARK: - High-contrast focus chrome (tvOS)

private struct TVOSHighContrastFocusRectBorder: ViewModifier {

    let cornerRadius: CGFloat

    @Environment(\.isFocused)
    private var isFocused

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.white : Color.clear,
                        lineWidth: isFocused ? 4 : 0
                    )
                    .allowsHitTesting(false)
            }
    }
}

private struct TVOSHighContrastFocusCircleBorderModifier: ViewModifier {

    @Environment(\.isFocused)
    private var isFocused

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .strokeBorder(
                        isFocused ? Color.white : Color.clear,
                        lineWidth: isFocused ? 4 : 0
                    )
                    .allowsHitTesting(false)
            }
    }
}
