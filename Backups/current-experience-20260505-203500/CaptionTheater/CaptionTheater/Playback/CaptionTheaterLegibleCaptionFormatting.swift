//
//  CaptionTheaterLegibleCaptionFormatting.swift
//  CaptionTheater
//
//  Converts AVFoundation legible ``NSAttributedString`` payloads into plain caption lines for SwiftUI.
//

import Foundation

/// Flattens attributed legible samples into display strings for the Caption Theater band.
///
/// AVFoundation may vend multiple attributed strings per sample (for example stacked rows). This helper trims
/// runs and joins non-empty lines with newlines so SwiftUI can render them without leaking markup attributes.
enum CaptionTheaterLegibleCaptionFormatting {

    /// Concatenates legible runs into plain text suitable for ``Text`` in the caption band.
    static func plainCaptionText(from attributedStrings: [NSAttributedString]) -> String {
        attributedStrings
            .map(\.string)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Prefer ``plainCaptionText(from:)``; if that is empty, joins raw ``NSAttributedString/string`` payloads so markup-heavy cues still surface text.
    static func resolvedPlainCaptionText(from attributedStrings: [NSAttributedString]) -> String {
        let normalizedRuns = plainCaptionText(from: attributedStrings)
        if !normalizedRuns.isEmpty {
            return normalizedRuns
        }
        let rawJoined = attributedStrings.map(\.string).joined(separator: "\n")
        return rawJoined.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
