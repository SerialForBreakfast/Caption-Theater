//
//  CaptionTheaterLegibleCaptionFormattingTests.swift
//  CaptionTheaterTests
//

import Foundation
import Testing

@testable import CaptionTheater

struct CaptionTheaterLegibleCaptionFormattingTests {

    @Test func joinsTrimmedNonEmptyAttributedRunsWithNewlines() {
        let runs = [
            NSAttributedString(string: "  first line  \n"),
            NSAttributedString(string: ""),
            NSAttributedString(string: "second")
        ]
        let merged = CaptionTheaterLegibleCaptionFormatting.plainCaptionText(from: runs)
        #expect(merged == "first line\nsecond")
    }

    @Test func dropsPureWhitespaceRuns() {
        let runs = [
            NSAttributedString(string: "   \n\t ")
        ]
        let merged = CaptionTheaterLegibleCaptionFormatting.plainCaptionText(from: runs)
        #expect(merged.isEmpty)
    }

    @Test func resolvedPlainCaptionMatchesPlainWhenFilteredRunsProduceText() {
        let runs = [NSAttributedString(string: "  hello  ")]
        let resolved = CaptionTheaterLegibleCaptionFormatting.resolvedPlainCaptionText(from: runs)
        #expect(resolved == "hello")
    }
}
