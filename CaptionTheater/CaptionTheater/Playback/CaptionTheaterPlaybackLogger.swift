//
//  CaptionTheaterPlaybackLogger.swift
//  CaptionTheater
//
//  Structured console logging for AVPlayer / item lifecycle (engineering verification).
//

import OSLog

/// Subsystem-scoped logging for playback diagnostics (`Console.app`: Subsystem = bundle ID).
///
/// Categories include **`PlaybackFlow`** (pipeline), **`PlaybackFocus`** (tvOS Siri Remote focus — ``playbackFocus(_:)``), and error-level messages from ``playbackFailure(_:)``.
///
/// Use this for correlating app-owned steps with system messages such as `FigStreamPlayer` / `WebVTT`
/// failures that originate outside Caption Theater.
enum CaptionTheaterPlaybackLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "CaptionTheater"

    private static let playbackFlow = Logger(subsystem: subsystem, category: "PlaybackFlow")

    private static let focusChannel = Logger(subsystem: subsystem, category: "PlaybackFocus")

    /// General playback pipeline milestones (URL resolution, aspect load, play commands).
    static func playbackFlow(_ message: String) {
        playbackFlow.info("\(message, privacy: .public)")
    }

    /// tvOS focus / movement diagnostics (filter in Console: Category = `PlaybackFocus`).
    static func playbackFocus(_ message: String) {
        focusChannel.info("\(message, privacy: .public)")
    }

    /// Failures that block or interrupt decoding / playback.
    static func playbackFailure(_ message: String) {
        playbackFlow.error("\(message, privacy: .public)")
    }

    /// Secondary detail (KVO churn, retry loops) at debug level to reduce noise in default Console filters.
    static func playbackDebug(_ message: String) {
        playbackFlow.debug("\(message, privacy: .public)")
    }
}
