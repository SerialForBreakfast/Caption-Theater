//
//  CaptionTheaterCaptionTextPreferences.swift
//  CaptionTheater
//
//  User-facing caption typography presets for the expanded caption-reading region (MVP placeholder → renderer).
//

import SwiftUI
import UIKit

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
    /// ``standard`` uses the resolved **Caption 1** text style plus **2 pt** so the default band stays readable without jumping to the next semantic notch (``.large`` / ``.callout``).
    var captionOverlayFont: Font {
        switch self {
        case .standard:
            let basePoints = UIFont.preferredFont(forTextStyle: .caption1).pointSize
            return Font.system(size: basePoints + 2, weight: .regular, design: .default)
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

    /// Default stored value when unset.
    static let defaultTextSizeRawValue = CaptionTheaterCaptionTextSizePreset.standard.rawValue
}
