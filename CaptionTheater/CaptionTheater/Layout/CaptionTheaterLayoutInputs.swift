//
//  CaptionTheaterLayoutInputs.swift
//  CaptionTheater
//
//  MVP layout inputs derived from container geometry and presentation aspect ratio—not pixel bar detection.
//

import CoreGraphics
import Foundation

/// Per-edge padding applied **inside** the container before aspect-fit math (tvOS safe area, overscan, or QA simulation).
///
/// Output rects from ``CaptionTheaterLayoutEngine`` remain in **container** coordinates: origin is offset by the
/// inset’s top-left corner so SwiftUI/UIKit hosts can place overlays with the same numbers returned for video frames.
nonisolated struct CaptionTheaterLayoutContentInsets: Equatable, Sendable {

    let top: Double
    let left: Double
    let bottom: Double
    let right: Double

    /// No padding; layout uses the full ``CaptionTheaterLayoutInputs/containerWidth`` × ``CaptionTheaterLayoutInputs/containerHeight``.
    static let zero = CaptionTheaterLayoutContentInsets(top: 0, left: 0, bottom: 0, right: 0)

    init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    /// Uniform inset on all edges (typical overscan or symmetric safe-area modeling).
    init(uniform: Double) {
        top = uniform
        left = uniform
        bottom = uniform
        right = uniform
    }
}

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

    /// Shrinks the usable layout region; usually ``GeometryProxy/safeAreaInsets`` on tvOS plus any engineering overscan slack.
    let contentInsets: CaptionTheaterLayoutContentInsets

    /// Creates normalized inputs for the layout engine.
    ///
    /// - Parameters:
    ///   - containerSize: View bounds hosting the video layer.
    ///   - pictureAspectRatioWidthOverHeight: Must be finite and strictly positive.
    ///   - contentInsets: Safe area / overscan padding; defaults to no inset.
    init(
        containerSize: CGSize,
        pictureAspectRatioWidthOverHeight: Double,
        contentInsets: CaptionTheaterLayoutContentInsets = .zero
    ) {
        containerWidth = Double(containerSize.width)
        containerHeight = Double(containerSize.height)
        self.pictureAspectRatioWidthOverHeight = pictureAspectRatioWidthOverHeight
        self.contentInsets = contentInsets
    }

    /// Validates numeric ranges required by ``CaptionTheaterLayoutEngine``.
    var isValid: Bool {
        guard
            containerWidth.isFinite, containerHeight.isFinite, containerWidth > 0, containerHeight > 0,
            pictureAspectRatioWidthOverHeight.isFinite, pictureAspectRatioWidthOverHeight > 0
        else {
            return false
        }

        let i = contentInsets
        guard i.top.isFinite, i.left.isFinite, i.bottom.isFinite, i.right.isFinite,
              i.top >= 0, i.left >= 0, i.bottom >= 0, i.right >= 0
        else {
            return false
        }

        let innerWidth = containerWidth - i.left - i.right
        let innerHeight = containerHeight - i.top - i.bottom
        return innerWidth > 0 && innerHeight > 0
    }
}
