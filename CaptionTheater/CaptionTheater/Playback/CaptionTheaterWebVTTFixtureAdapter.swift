//
//  CaptionTheaterWebVTTFixtureAdapter.swift
//  CaptionTheater
//
//  Minimal WebVTT fixture parser for deterministic local Caption Theater cues.
//

import Foundation

enum CaptionTheaterWebVTTFixtureAdapter {

    enum ParseError: Error, Equatable {
        case unreadablePlaylist(URL)
        case unreadableSegment(URL)
    }

    /// Parses every segment referenced by a local WebVTT media playlist.
    static func cues(fromSegmentPlaylistURL playlistURL: URL) throws -> [CaptionTheaterCue] {
        guard let playlist = try? String(contentsOf: playlistURL, encoding: .utf8) else {
            throw ParseError.unreadablePlaylist(playlistURL)
        }

        var parsedCues: [CaptionTheaterCue] = []
        var seenKeys = Set<String>()
        let playlistRoot = playlistURL.deletingLastPathComponent()

        for rawLine in playlist.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            let segmentURL = playlistRoot.appendingPathComponent(line, isDirectory: false)
            guard let segment = try? String(contentsOf: segmentURL, encoding: .utf8) else {
                throw ParseError.unreadableSegment(segmentURL)
            }

            for cue in cues(fromWebVTTText: segment) {
                let key = "\(cue.id)|\(cue.startSeconds)|\(cue.endSeconds)|\(cue.text)"
                guard !seenKeys.contains(key) else {
                    continue
                }
                seenKeys.insert(key)
                parsedCues.append(cue)
            }
        }

        return parsedCues.sorted { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds {
                return lhs.id < rhs.id
            }
            return lhs.startSeconds < rhs.startSeconds
        }
    }

    /// Parses a minimal WebVTT payload into normalized cues.
    static func cues(fromWebVTTText text: String) -> [CaptionTheaterCue] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [CaptionTheaterCue] = []

        for block in blocks {
            let lines = block
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }

            let cueID = timingIndex > 0 ? lines[timingIndex - 1] : "cue-\(cues.count)"
            guard let timing = parseTimingLine(lines[timingIndex]) else {
                continue
            }
            guard timingIndex + 1 < lines.count else {
                continue
            }

            let cueText = lines[(timingIndex + 1)...]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let plainText = strippedCueMarkup(from: cueText)
            guard !plainText.isEmpty, timing.endSeconds > timing.startSeconds else {
                continue
            }

            let intent = inferredIntent(from: plainText)
            cues.append(
                CaptionTheaterCue(
                    id: cueID,
                    startSeconds: timing.startSeconds,
                    endSeconds: timing.endSeconds,
                    text: plainText,
                    intent: intent,
                    persistencePolicy: persistencePolicy(for: intent)
                )
            )
        }

        return cues
    }

    private static func parseTimingLine(_ line: String) -> (startSeconds: Double, endSeconds: Double)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else {
            return nil
        }

        let startText = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = parts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .first ?? ""

        guard let startSeconds = parseTimestamp(startText),
              let endSeconds = parseTimestamp(endText)
        else {
            return nil
        }

        return (startSeconds, endSeconds)
    }

    private static func parseTimestamp(_ timestamp: String) -> Double? {
        let parts = timestamp.components(separatedBy: ":")
        guard parts.count == 2 || parts.count == 3 else {
            return nil
        }

        let secondsPart = parts.last ?? ""
        let secondsPieces = secondsPart.components(separatedBy: ".")
        guard secondsPieces.count <= 2,
              let wholeSeconds = Double(secondsPieces[0])
        else {
            return nil
        }

        let milliseconds: Double
        if secondsPieces.count == 2 {
            let fraction = secondsPieces[1]
            guard let fractionValue = Double(fraction) else {
                return nil
            }
            milliseconds = fractionValue / pow(10, Double(fraction.count))
        } else {
            milliseconds = 0
        }

        if parts.count == 3 {
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1])
            else {
                return nil
            }
            return hours * 3600 + minutes * 60 + wholeSeconds + milliseconds
        } else {
            guard let minutes = Double(parts[0]) else {
                return nil
            }
            return minutes * 60 + wholeSeconds + milliseconds
        }
    }

    private static func strippedCueMarkup(from text: String) -> String {
        let pattern = #"<[^>]+>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func inferredIntent(from text: String) -> CaptionTheaterCueIntent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            return .sdh
        }
        if trimmed.lowercased().contains("[silent") || trimmed.lowercased().contains("[low rumble") {
            return .sdh
        }
        return .dialogue
    }

    private static func persistencePolicy(for intent: CaptionTheaterCueIntent) -> CaptionTheaterCuePersistencePolicy {
        switch intent {
        case .dialogue, .sdh, .unknown:
            return .eligibleForRetention
        case .forced, .lyrics, .legal:
            return .authoredTimingOnly
        }
    }
}
