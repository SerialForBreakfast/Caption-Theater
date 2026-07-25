//
//  CaptionTheaterCuePersistencePolicy.swift
//  CaptionTheater
//
//  Pure caption visibility rules for current and retained Caption Theater rows.
//

import Foundation

struct CaptionTheaterCuePersistenceConfiguration: Equatable, Sendable {

    let retainedCueMaximumAgeSeconds: Double
    let maximumVisibleRows: Int
    let retainedCharacterBudget: Int

    static let `default` = CaptionTheaterCuePersistenceConfiguration(
        retainedCueMaximumAgeSeconds: 12,
        maximumVisibleRows: 4,
        retainedCharacterBudget: 360
    )
}

enum CaptionTheaterCuePersistencePolicyEngine {

    static func visibleRows(
        cues: [CaptionTheaterCue],
        playbackSeconds: Double,
        configuration: CaptionTheaterCuePersistenceConfiguration = .default
    ) -> [CaptionTheaterVisibleCueRow] {
        guard playbackSeconds.isFinite,
              configuration.maximumVisibleRows > 0,
              configuration.retainedCharacterBudget > 0
        else {
            return []
        }

        let sortedCues = cues.sorted { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds {
                return lhs.id < rhs.id
            }
            return lhs.startSeconds < rhs.startSeconds
        }

        let currentCues = sortedCues.filter { cue in
            cue.persistencePolicy != .nativeFallback
                && cue.startSeconds <= playbackSeconds
                && playbackSeconds < cue.endSeconds
        }

        let currentRows = currentCues
            .prefix(configuration.maximumVisibleRows)
            .map { CaptionTheaterVisibleCueRow(cue: $0, state: .current) }

        let remainingRowSlots = configuration.maximumVisibleRows - currentRows.count
        guard remainingRowSlots > 0 else {
            return Array(currentRows)
        }

        var retainedRows: [CaptionTheaterVisibleCueRow] = []
        var retainedCharacters = 0
        let currentIDs = Set(currentCues.map(\.id))

        let retainedCandidates = sortedCues
            .filter { cue in
                cue.persistencePolicy == .eligibleForRetention
                    && !currentIDs.contains(cue.id)
                    && cue.endSeconds <= playbackSeconds
                    && playbackSeconds - cue.endSeconds <= configuration.retainedCueMaximumAgeSeconds
            }
            .sorted { lhs, rhs in
                if lhs.endSeconds == rhs.endSeconds {
                    return lhs.id > rhs.id
                }
                return lhs.endSeconds > rhs.endSeconds
            }

        for cue in retainedCandidates {
            let nextCount = retainedCharacters + cue.text.count
            guard nextCount <= configuration.retainedCharacterBudget else {
                continue
            }
            retainedRows.append(CaptionTheaterVisibleCueRow(cue: cue, state: .retained))
            retainedCharacters = nextCount
            if retainedRows.count >= remainingRowSlots {
                break
            }
        }

        return Array(currentRows) + retainedRows
    }
}
