//
//  CaptionTheaterCaptionTextPreferencesTests.swift
//  CaptionTheaterTests
//

import Testing
@testable import CaptionTheater

struct CaptionTheaterCaptionTextPreferencesTests {

    @Test func resolvedFallsBackForUnknownRawValue() {
        let fallback = CaptionTheaterCaptionTextSizePreset.resolved(fromStoredRaw: "not-a-preset")
        #expect(fallback == .standard)
    }

    @Test func allCasesRoundTripThroughRawValue() {
        for preset in CaptionTheaterCaptionTextSizePreset.allCases {
            let again = CaptionTheaterCaptionTextSizePreset.resolved(fromStoredRaw: preset.rawValue)
            #expect(again == preset)
        }
    }
}
