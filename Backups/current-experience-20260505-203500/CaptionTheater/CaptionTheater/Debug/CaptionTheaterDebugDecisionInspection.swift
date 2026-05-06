//
//  CaptionTheaterDebugDecisionInspection.swift
//  CaptionTheater
//
//  Pure mapping from eligibility snapshots and decisions into strings for debug UI.
//

import Foundation

/// Human-readable breakdown of one eligibility evaluation for debug tooling.
///
/// Built synchronously from a snapshot and ``CaptionTheaterDecision`` on any thread;
/// SwiftUI hosts should construct this on the main actor before updating views.
struct CaptionTheaterDebugDecisionInspection: Sendable {
    /// Summary headline (eligible vs native fallback vs uncertain).
    let outcomeHeadline: String
    /// Secondary line describing the primary reason enum when applicable.
    let outcomeDetail: String
    /// Snapshot inputs shown verbatim with engineering-friendly labels.
    let inputRows: [(label: String, value: String)]
    /// Evidence grouped for scanning (positive, negative, uncertain).
    let evidenceSections: [(title: String, rows: [(source: String, message: String)])]
    /// Placeholder until a playback coordinator emits real transitions.
    let lifecycleTransitionNote: String

    /// Builds an inspection model from a scenario title/summary and engine output.
    ///
    /// - Parameters:
    ///   - scenarioTitle: Short list title for context.
    ///   - scenarioSummary: Product-facing explanation shown above inputs.
    ///   - snapshot: Inputs that produced `decision`.
    ///   - decision: Output from ``CaptionTheaterDecisionEngine/decision(for:)``.
    nonisolated init(
        scenarioTitle: String,
        scenarioSummary: String,
        snapshot: CaptionTheaterEligibilitySnapshot,
        decision: CaptionTheaterDecision
    ) {
        inputRows = [
            ("Scenario", scenarioTitle),
            ("Summary", scenarioSummary),
            ("User enabled Caption Theater", snapshot.isEnabledByUser ? "Yes" : "No"),
            ("Ad playback state", String(describing: snapshot.adPlaybackState)),
            ("Subtitle state", String(describing: snapshot.subtitleState)),
            ("Viewport state", String(describing: snapshot.viewportState)),
            ("Protected content state", String(describing: snapshot.protectedContentState)),
        ]

        lifecycleTransitionNote =
            "No playback coordinator is attached yet; this panel evaluates a single snapshot. Seek, track changes, and discontinuity resets will appear here once wired."

        switch decision {
        case .eligible:
            outcomeHeadline = "Caption Theater eligible"
            outcomeDetail = "All gates passed for this snapshot."
        case let .ineligible(reason, _):
            outcomeHeadline = "Native playback (ineligible)"
            outcomeDetail = String(describing: reason)
        case let .uncertain(reason, _):
            outcomeHeadline = "Uncertain — failing closed to native playback"
            outcomeDetail = String(describing: reason)
        }

        let grouped = Self.groupedEvidence(from: decision)
        evidenceSections = [
            ("Supporting evidence", grouped.positive),
            ("Blocking evidence", grouped.negative),
            ("Uncertain evidence", grouped.uncertain),
        ]
    }

    nonisolated private static func groupedEvidence(from decision: CaptionTheaterDecision)
        -> (positive: [(source: String, message: String)], negative: [(source: String, message: String)], uncertain: [(source: String, message: String)])
    {
        let evidence: [CaptionTheaterEvidence]
        switch decision {
        case let .eligible(rows):
            evidence = rows
        case let .ineligible(_, rows):
            evidence = rows
        case let .uncertain(_, rows):
            evidence = rows
        }

        var positive: [(String, String)] = []
        var negative: [(String, String)] = []
        var uncertain: [(String, String)] = []

        for row in evidence {
            let pair = (String(describing: row.source), row.message)
            switch row.polarity {
            case .positive:
                positive.append(pair)
            case .negative:
                negative.append(pair)
            case .uncertain:
                uncertain.append(pair)
            }
        }

        return (positive, negative, uncertain)
    }
}
