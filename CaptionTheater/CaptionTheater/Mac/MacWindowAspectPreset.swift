//
//  MacWindowAspectPreset.swift
//  CaptionTheater
//
//  Native macOS window aspect presets for demo and screenshot workflows.
//

import CoreGraphics

/// Window aspect-ratio presets used by the macOS target's Window menu.
enum MacWindowAspectPreset: String, CaseIterable, Identifiable, Sendable {

    case freeform
    case fourByThree
    case sixteenByNine
    case twentyOneByNine
    case scope239
    case sourceAspect

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .freeform:
            return "Freeform"
        case .fourByThree:
            return "4:3"
        case .sixteenByNine:
            return "16:9"
        case .twentyOneByNine:
            return "21:9"
        case .scope239:
            return "2.39:1"
        case .sourceAspect:
            return "Source Aspect"
        }
    }

    /// Fixed width÷height ratio. `nil` means no fixed ratio.
    func ratio(sourceAspect: CGFloat?) -> CGFloat? {
        switch self {
        case .freeform:
            return nil
        case .fourByThree:
            return 4.0 / 3.0
        case .sixteenByNine:
            return 16.0 / 9.0
        case .twentyOneByNine:
            return 21.0 / 9.0
        case .scope239:
            return 2.39
        case .sourceAspect:
            return sourceAspect
        }
    }

    /// Returns a content size with the requested aspect ratio while preserving the current width where practical.
    func contentSize(
        fitting currentSize: CGSize,
        sourceAspect: CGFloat?,
        minimumSize: CGSize = CGSize(width: 640, height: 360),
        maximumSize: CGSize = CGSize(width: 2560, height: 1600)
    ) -> CGSize {
        guard let ratio = ratio(sourceAspect: sourceAspect), ratio > 0 else {
            return currentSize
        }

        let width = min(max(currentSize.width, minimumSize.width), maximumSize.width)
        var height = width / ratio

        if height < minimumSize.height {
            height = minimumSize.height
        } else if height > maximumSize.height {
            height = maximumSize.height
        }

        let adjustedWidth = min(max(height * ratio, minimumSize.width), maximumSize.width)
        return CGSize(width: adjustedWidth, height: height)
    }
}

