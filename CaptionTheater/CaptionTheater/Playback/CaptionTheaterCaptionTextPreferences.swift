//
//  CaptionTheaterCaptionTextPreferences.swift
//  CaptionTheater
//
//  User-facing caption typography presets for the expanded caption-reading region (MVP placeholder → renderer).
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Named caption sizes for Caption Theater overlays when ``CaptionTheaterLayoutGeometry/captionReadingRect`` supplies extra vertical space.
///
/// Larger bands (native ultra-wide on a 16:9 panel under ``resizeAspect``) intentionally enable **larger closed captions**
/// without obscuring active picture. Native ``AVPlayer`` legible streams remain independent until Phase 4 wires rendering.
enum CaptionTheaterCaptionTextSizePreset: String, CaseIterable, Identifiable, Sendable {

    case standard
    case large
    case extraLarge
    case maxReadability

    var id: String { rawValue }

    /// Human-readable label for menus and settings.
    var menuTitle: String {
        switch self {
        case .standard:
            return "Standard"
        case .large:
            return "Large"
        case .extraLarge:
            return "Extra Large"
        case .maxReadability:
            return "Maximum readability"
        }
    }

    /// SwiftUI font for MVP caption overlays; Phase 4 renderer should honor the same semantic steps with Dynamic Type.
    ///
    /// ``standard`` maps to **Subheadline** so letterboxed caption bands use more reading width without jumping to ``.large``.
    var captionOverlayFont: Font {
        switch self {
        case .standard:
            #if os(macOS)
            let basePoints = NSFont.systemFontSize
            #else
            let basePoints = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
            #endif
            return Font.system(size: basePoints, weight: .regular, design: .default)
        case .large:
            return .callout
        case .extraLarge:
            return .title3
        case .maxReadability:
            return .title2
        }
    }

    /// Resolved preset from persisted storage; unknown raw values fall back to ``standard``.
    static func resolved(fromStoredRaw raw: String) -> CaptionTheaterCaptionTextSizePreset {
        CaptionTheaterCaptionTextSizePreset(rawValue: raw) ?? .standard
    }
}

/// Keys and helpers for persisting caption appearance across launches.
enum CaptionTheaterCaptionTextPreferences {

    /// `UserDefaults` / `@AppStorage` key for ``CaptionTheaterCaptionTextSizePreset/rawValue``.
    static let textSizePresetStorageKey = "CaptionTheaterCaptionTextSizePreset"

    /// Default stored value when unset (new installs favor **Large** for ultra-wide layouts with extra band space).
    static let defaultTextSizeRawValue = CaptionTheaterCaptionTextSizePreset.large.rawValue
}
