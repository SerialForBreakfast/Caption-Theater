//
//  CaptionTheaterScrollingCaptionPolicy.swift
//  CaptionTheater
//
//  Pure rules for building scrolling subtitle history from repeated legible-output deliveries.
//

import Foundation

/// Decides how incoming legible plain text updates **newest-first** scrolling rows.
///
/// AVFoundation may invoke the legible delegate many times per cue with identical strings; this policy **prepends**
/// a row only when the payload differs from the current newest row so history advances once per distinct cue.
enum CaptionTheaterScrollingCaptionPolicy {

    /// Maximum rows retained (oldest dropped after prepending).
    static let maxScrollingCueEntries = 80

    /// Returns entries after accepting `incomingPlain`, or `nil` when `incomingPlain` is empty or whitespace-only.
    static func entriesByPrependingDistinctCue(
        previousEntries: [CaptionTheaterScrollingCueEntry],
        incomingPlain: String
    ) -> [CaptionTheaterScrollingCueEntry]? {
        let trimmed = incomingPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        guard trimmed != previousEntries.first?.text else {
            return previousEntries
        }
        let row = CaptionTheaterScrollingCueEntry(text: trimmed)
        let merged = [row] + previousEntries
        if merged.count <= maxScrollingCueEntries {
            return merged
        }
        return Array(merged.prefix(maxScrollingCueEntries))
    }
}
