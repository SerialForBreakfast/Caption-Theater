//
//  CaptionTheaterPlaybackUILayout.swift
//  CaptionTheater
//
//  Thresholds for fullscreen playback UX (ultra-wide prompt vs standard HDTV-shaped pictures).
//

import CoreGraphics

/// Presentation constants for the tvOS playback shell (fullscreen MVP).
enum CaptionTheaterPlaybackUILayout {

    /// Picture aspect (width ÷ height) above this value is treated as **ultra-wide** vs nominal 16∶9 HDTV.
    ///
    /// Encoded rasters near `1920×800` (~2.39∶1) exceed this; vanilla `1920×1080` does not.
    static let ultrawideAspectRatioThresholdWidthOverHeight: CGFloat = 16.0 / 9.0 + 0.001

    /// Scope-style fallback width÷height when HTTP(S) ladders expose a 16∶9 decode raster over letterboxed scope.
    ///
    /// Applied **only** after the viewer opts into Caption Theater on remote streams—until CT‑0601 consumes variant tags directly.
    static let remoteScopeFallbackAspectRatioWidthOverHeight: CGFloat = 2.39
}
