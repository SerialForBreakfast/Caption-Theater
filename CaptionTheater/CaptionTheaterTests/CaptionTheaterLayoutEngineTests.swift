//
//  CaptionTheaterLayoutEngineTests.swift
//  CaptionTheaterTests
//

import CoreGraphics
import Testing
@testable import CaptionTheater

struct CaptionTheaterLayoutEngineTests {

    private let engine = CaptionTheaterLayoutEngine()

    /// Ultra-wide picture on a 16:9 container yields letterboxing with predictable bottom band height.
    @Test func ultraWideOn16x9ProducesLetterboxBandsAndPreservesAspect() {
        let inputs = CaptionTheaterLayoutInputs(
            containerSize: CGSize(width: 1920, height: 1080),
            pictureAspectRatioWidthOverHeight: 2.39
        )

        guard let topPinned = engine.geometry(for: inputs, mode: .captionTheaterAspectFitTopPinned) else {
            Issue.record("Expected geometry for valid ultra-wide inputs.")
            return
        }

        #expect(topPinned.activePictureRect.width == 1920)
        let expectedHeight = 1920 / 2.39
        #expect(abs(Double(topPinned.activePictureRect.height) - expectedHeight) < 0.01)
        #expect(topPinned.activePictureRect.minX == 0)
        #expect(topPinned.activePictureRect.minY == 0)

        let expectedCaptionHeight = 1080 - expectedHeight
        #expect(abs(Double(topPinned.captionReadingRect.height) - expectedCaptionHeight) < 0.01)
        #expect(topPinned.captionReadingRect.minY == topPinned.activePictureRect.maxY)

        guard let centered = engine.geometry(for: inputs, mode: .nativeAspectFitCentered) else {
            Issue.record("Expected centered geometry.")
            return
        }

        let expectedY = (1080 - expectedHeight) / 2
        #expect(abs(Double(centered.activePictureRect.minY) - expectedY) < 0.01)
        #expect(centered.captionReadingRect.height < topPinned.captionReadingRect.height)
    }

    /// Full-frame 16:9 picture on 16:9 container consumes the canvas (no separate caption band below picture).
    @Test func fullFrame16x9FillsContainerHeight() {
        let inputs = CaptionTheaterLayoutInputs(
            containerSize: CGSize(width: 1920, height: 1080),
            pictureAspectRatioWidthOverHeight: 16 / 9
        )

        guard let geo = engine.geometry(for: inputs, mode: .captionTheaterAspectFitTopPinned) else {
            Issue.record("Expected geometry.")
            return
        }

        #expect(geo.activePictureRect.height == 1080)
        #expect(geo.captionReadingRect.height == 0)
    }

    @Test func invalidInputsReturnNil() {
        let bad = CaptionTheaterLayoutInputs(
            containerSize: .zero,
            pictureAspectRatioWidthOverHeight: 2.39
        )

        #expect(engine.geometry(for: bad, mode: .nativeAspectFitCentered) == nil)
    }
}
