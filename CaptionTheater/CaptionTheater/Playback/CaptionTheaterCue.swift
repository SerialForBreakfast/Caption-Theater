//
//  CaptionTheaterCue.swift
//  CaptionTheater
//
//  Normalized caption cue model for deterministic Caption Theater persistence rendering.
//

import Foundation

/// Broad cue category used by persistence policy without tying the renderer to one subtitle format.
enum CaptionTheaterCueIntent: String, Equatable, Sendable {
    case dialogue
    case sdh
    case forced
    case lyrics
    case legal
    case unknown
}

/// Whether a cue may remain visible after its authored end time.
enum CaptionTheaterCuePersistencePolicy: Equatable, Sendable {
    case eligibleForRetention
    case authoredTimingOnly
    case nativeFallback
}

/// A single normalized subtitle/caption cue.
struct CaptionTheaterCue: Identifiable, Equatable, Sendable {

    let id: String
    let startSeconds: Double
    let endSeconds: Double
    let text: String
    let intent: CaptionTheaterCueIntent
    let persistencePolicy: CaptionTheaterCuePersistencePolicy

    init(
        id: String,
        startSeconds: Double,
        endSeconds: Double,
        text: String,
        intent: CaptionTheaterCueIntent = .dialogue,
        persistencePolicy: CaptionTheaterCuePersistencePolicy = .eligibleForRetention
    ) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
        self.intent = intent
        self.persistencePolicy = persistencePolicy
    }
}

/// Visual state for a cue row in the Caption Theater reading band.
enum CaptionTheaterVisibleCueRowState: Equatable, Sendable {
    case current
    case retained
}

/// Render-ready row computed from a cue timeline at a specific playback time.
struct CaptionTheaterVisibleCueRow: Identifiable, Equatable, Sendable {

    let id: String
    let cueID: String
    let text: String
    let state: CaptionTheaterVisibleCueRowState

    init(cue: CaptionTheaterCue, state: CaptionTheaterVisibleCueRowState) {
        cueID = cue.id
        text = cue.text
        self.state = state
        id = "\(state)-\(cue.id)"
    }
}
