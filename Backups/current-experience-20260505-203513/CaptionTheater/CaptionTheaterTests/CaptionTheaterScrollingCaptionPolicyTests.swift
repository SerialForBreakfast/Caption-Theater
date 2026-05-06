//
//  CaptionTheaterScrollingCaptionPolicyTests.swift
//  CaptionTheaterTests
//

import Foundation
import Testing

@testable import CaptionTheater

struct CaptionTheaterScrollingCaptionPolicyTests {

    @Test func prependsDistinctCueNewestFirst() {
        let first = CaptionTheaterScrollingCueEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "Alpha")
        let prior = [first]
        guard let next = CaptionTheaterScrollingCaptionPolicy.entriesByPrependingDistinctCue(
            previousEntries: prior,
            incomingPlain: "Beta"
        ) else {
            Issue.record("Expected non-nil entries.")
            return
        }
        #expect(next.count == 2)
        #expect(next[0].text == "Beta")
        #expect(next[1].text == "Alpha")
    }

    @Test func ignoresRepeatedDeliveryMatchingNewestRow() {
        let row = CaptionTheaterScrollingCueEntry(text: "Same")
        let prior = [row]
        guard let next = CaptionTheaterScrollingCaptionPolicy.entriesByPrependingDistinctCue(
            previousEntries: prior,
            incomingPlain: "Same"
        ) else {
            Issue.record("Expected non-nil entries.")
            return
        }
        #expect(next.count == 1)
        #expect(next[0].id == row.id)
    }

    @Test func emptyPayloadReturnsNil() {
        let prior = [CaptionTheaterScrollingCueEntry(text: "Keep")]
        let next = CaptionTheaterScrollingCaptionPolicy.entriesByPrependingDistinctCue(
            previousEntries: prior,
            incomingPlain: "   \n"
        )
        #expect(next == nil)
    }

    @Test func trimsWhitespaceBeforeCompareAndStore() {
        guard let next = CaptionTheaterScrollingCaptionPolicy.entriesByPrependingDistinctCue(
            previousEntries: [],
            incomingPlain: "  hello  "
        ) else {
            Issue.record("Expected non-nil entries.")
            return
        }
        #expect(next.count == 1)
        #expect(next[0].text == "hello")
    }

    @Test func capsHistoryAtMaxEntries() {
        var entries: [CaptionTheaterScrollingCueEntry] = []
        for index in 0..<90 {
            guard let next = CaptionTheaterScrollingCaptionPolicy.entriesByPrependingDistinctCue(
                previousEntries: entries,
                incomingPlain: "line \(index)"
            ) else {
                Issue.record("Expected non-nil at index \(index).")
                return
            }
            entries = next
        }
        #expect(entries.count == CaptionTheaterScrollingCaptionPolicy.maxScrollingCueEntries)
        #expect(entries.first?.text == "line 89")
        #expect(entries.last?.text == "line 10")
    }
}
