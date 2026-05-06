//
//  CaptionTheaterLayoutEngine.swift
//  CaptionTheater
//
//  Computes aspect-fit geometry for native vs top-pinned cinematic MVP layouts (CT-0303 slice).
//

import CoreGraphics
import Foundation

/// How the aspect-fit picture is positioned vertically inside the container for MVP demos.
nonisolated enum CaptionTheaterLayoutPresentationMode: Equatable, Sendable {
    /// Matches default AVKit-style vertical centering under ``AVLayerVideoGravity/resizeAspect``.
    case nativeAspectFitCentered
    /// Pins the picture to the **top** of the container so the bottom unused band becomes caption-safe space.
    case captionTheaterAspectFitTopPinned
}

/// Stateless calculator mapping ``CaptionTheaterLayoutInputs`` into rects.
///
/// **Policy:** MVP relies on **mathematical aspect-fit** only—no pixel classification (CT-0302). Pair with
/// ``AVPlayerLayer`` using ``AVLayerVideoGravity/resizeAspect`` exclusively; aspect-fill is excluded from this milestone.
nonisolated struct CaptionTheaterLayoutEngine: Sendable {

    init() {}

    /// Returns aspect-fit geometry or `nil` when inputs are invalid.
    func geometry(for inputs: CaptionTheaterLayoutInputs, mode: CaptionTheaterLayoutPresentationMode)
        -> CaptionTheaterLayoutGeometry?
    {
        guard inputs.isValid else {
            return nil
        }

        let wc = inputs.containerWidth
        let hc = inputs.containerHeight
        let ar = inputs.pictureAspectRatioWidthOverHeight

        let containerAspect = wc / hc

        let pictureWidth: Double
        let pictureHeight: Double

        if ar > containerAspect {
            pictureWidth = wc
            pictureHeight = wc / ar
        } else {
            pictureHeight = hc
            pictureWidth = hc * ar
        }

        let horizontalInset = (wc - pictureWidth) / 2

        let originY: Double
        switch mode {
        case .nativeAspectFitCentered:
            originY = (hc - pictureHeight) / 2
        case .captionTheaterAspectFitTopPinned:
            originY = 0
        }

        let pictureRect = CGRect(
            x: horizontalInset,
            y: originY,
            width: pictureWidth,
            height: pictureHeight
        )

        let captionTop = originY + pictureHeight
        let captionHeight = max(0, hc - captionTop)
        let captionRect = CGRect(x: 0, y: captionTop, width: wc, height: captionHeight)

        return CaptionTheaterLayoutGeometry(activePictureRect: pictureRect, captionReadingRect: captionRect)
    }
}
