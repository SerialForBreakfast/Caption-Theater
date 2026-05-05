//
//  CaptionTheaterLayoutInputs.swift
//  CaptionTheater
//
//  MVP layout inputs derived from container geometry and presentation aspect ratio—not pixel bar detection.
//

import CoreGraphics
import Foundation

/// Logical inputs for ``CaptionTheaterLayoutEngine`` before Phase 3 pixel sampling exists.
///
/// Callers supply the **picture** aspect ratio (width ÷ height)—for example ~2.39 for cinematic scope—typically
/// from ``AVAssetTrack`` dimensions plus ``preferredTransform``, or from trusted provider metadata. This avoids
/// inferring letterboxing from luminance in encoded frames (see CT-0302 deferral for MVP).
nonisolated struct CaptionTheaterLayoutInputs: Equatable, Sendable {

    /// Host bounds width in points.
    let containerWidth: Double

    /// Host bounds height in points.
    let containerHeight: Double

    /// Presentation aspect ratio of the active picture: **width divided by height** (e.g. 2.39:1 → ~2.39).
    let pictureAspectRatioWidthOverHeight: Double

    /// Creates normalized inputs for the layout engine.
    ///
    /// - Parameters:
    ///   - containerSize: View bounds hosting the video layer.
    ///   - pictureAspectRatioWidthOverHeight: Must be finite and strictly positive.
    init(containerSize: CGSize, pictureAspectRatioWidthOverHeight: Double) {
        containerWidth = Double(containerSize.width)
        containerHeight = Double(containerSize.height)
        self.pictureAspectRatioWidthOverHeight = pictureAspectRatioWidthOverHeight
    }

    /// Validates numeric ranges required by ``CaptionTheaterLayoutEngine``.
    var isValid: Bool {
        containerWidth.isFinite && containerHeight.isFinite && containerWidth > 0 && containerHeight > 0
            && pictureAspectRatioWidthOverHeight.isFinite && pictureAspectRatioWidthOverHeight > 0
    }
}
