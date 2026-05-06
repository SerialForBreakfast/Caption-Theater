//
//  CaptionTheaterScrollingCueEntry.swift
//  CaptionTheater
//
//  Identifiable rows for scrolling subtitle history (newest-first ordering).
//

import Foundation

/// One subtitle payload shown as a row in the Caption Theater scrolling band.
///
/// Rows are ordered **newest-first** in ``CaptionTheaterPlaybackShellViewModel/captionScrollingCueEntries`` so SwiftUI can stack
/// later cues visually below earlier ones.
struct CaptionTheaterScrollingCueEntry: Identifiable, Equatable, Sendable {

    let id: UUID

    /// Trimmed plain text for this delivery (may contain internal newlines).
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}
