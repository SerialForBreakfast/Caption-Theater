//
//  CaptionTheaterLayoutGeometry.swift
//  CaptionTheater
//
//  Deterministic rectangles for video and caption regions in host container coordinates (including safe-area padding).
//

import CoreGraphics
import Foundation

/// Output rectangles for video pinning and caption overlay placement (points), in **container** coordinates.
///
/// When ``CaptionTheaterLayoutInputs/contentInsets`` trim the layout region, origins shift away from the container edges
/// while aspect-fit math stays confined to the inset area.
nonisolated struct CaptionTheaterLayoutGeometry: Equatable, Sendable {

    /// Aspect-fit picture rectangle inside the container (matches ``AVLayerVideoGravity/resizeAspect`` framing).
    let activePictureRect: CGRect

    /// Lower unused band reserved for persistent captions in ``CaptionTheaterLayoutPresentationMode/captionTheaterAspectFitTopPinned``.
    ///
    /// May be ``CGRect.zero`` when the picture consumes the full container height (e.g. pillarboxed tall assets).
    /// Extra vertical extent supports **larger caption typography** without overlapping active picture; sizing policy is
    /// user-controlled via ``CaptionTheaterCaptionTextSizePreset`` until the persistence renderer consumes this rect directly.
    let captionReadingRect: CGRect

    /// Converts numeric layout into Core Graphics rects for SwiftUI or UIKit hosts.
    init(activePictureRect: CGRect, captionReadingRect: CGRect) {
        self.activePictureRect = activePictureRect
        self.captionReadingRect = captionReadingRect
    }
}
