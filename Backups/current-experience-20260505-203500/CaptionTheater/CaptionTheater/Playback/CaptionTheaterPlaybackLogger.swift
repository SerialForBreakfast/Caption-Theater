//
//  CaptionTheaterPlaybackLogger.swift
//  CaptionTheater
//
//  Structured console logging for AVPlayer / item lifecycle (engineering verification).
//

import OSLog

/// Subsystem-scoped logging for playback diagnostics (`Console.app` filter: Subsystem = bundle ID, Category = `PlaybackFlow`).
///
/// Use this for correlating app-owned steps with system messages such as `FigStreamPlayer` / `WebVTT`
/// failures that originate outside Caption Theater.
enum CaptionTheaterPlaybackLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "CaptionTheater"

    private static let playbackFlow = Logger(subsystem: subsystem, category: "PlaybackFlow")

    /// General playback pipeline milestones (URL resolution, aspect load, play commands).
    static func playbackFlow(_ message: String) {
        playbackFlow.info("\(message, privacy: .public)")
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
