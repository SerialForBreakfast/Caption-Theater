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

    /// Inner layout width or height must stay positive after subtracting insets.
    @Test func contentInsetsThatEliminateInnerWidthReturnNil() {
        let inputs = CaptionTheaterLayoutInputs(
            containerSize: CGSize(width: 100, height: 500),
            pictureAspectRatioWidthOverHeight: 2.39,
            contentInsets: CaptionTheaterLayoutContentInsets(top: 0, left: 50, bottom: 0, right: 51)
        )

        #expect(inputs.isValid == false)
        #expect(engine.geometry(for: inputs, mode: .nativeAspectFitCentered) == nil)
    }

    /// Reference “TV overscan” slack modeled as uniform per-edge insets shrinks the picture and shifts origins.
    @Test func uniformOverscanInsetsShrinkPictureAndOffsetFromContainerOrigin() {
        let without = CaptionTheaterLayoutInputs(
            containerSize: CGSize(width: 1920, height: 1080),
            pictureAspectRatioWidthOverHeight: 2.39,
            contentInsets: .zero
        )
        let overscan = CaptionTheaterLayoutContentInsets(uniform: 60)
        let withInset = CaptionTheaterLayoutInputs(
            containerSize: CGSize(width: 1920, height: 1080),
            pictureAspectRatioWidthOverHeight: 2.39,
            contentInsets: overscan
        )

        guard let base = engine.geometry(for: without, mode: .captionTheaterAspectFitTopPinned),
              let insetLayout = engine.geometry(for: withInset, mode: .captionTheaterAspectFitTopPinned)
        else {
            Issue.record("Expected both geometries.")
            return
        }

        let innerWidth = Double(1920 - 120)
        #expect(abs(Double(insetLayout.activePictureRect.width) - innerWidth) < 0.01)
        #expect(abs(Double(insetLayout.activePictureRect.minX) - 60) < 0.01)
        #expect(abs(Double(insetLayout.activePictureRect.minY) - 60) < 0.01)

        let baseAspect = base.activePictureRect.width / base.activePictureRect.height
        let insetAspect = insetLayout.activePictureRect.width / insetLayout.activePictureRect.height
        #expect(abs(baseAspect - insetAspect) < 0.001)

        #expect(insetLayout.captionReadingRect.minX == 60)
        #expect(abs(Double(insetLayout.captionReadingRect.width) - innerWidth) < 0.01)
        #expect(insetLayout.captionReadingRect.maxY <= 1080 - 60 + 0.01)
    }

    /// Hero top-pin stays aligned to the top of the **inset** region so captions sit in the lower inner band.
    @Test func asymmetricSafeAreaInsetsOffsetPictureAndCaptionHorizontally() {
        let inputs = CaptionTheaterLayoutInputs(
            containerSize: CGSize(width: 1920, height: 1080),
            pictureAspectRatioWidthOverHeight: 2.39,
            contentInsets: CaptionTheaterLayoutContentInsets(top: 10, left: 80, bottom: 90, right: 40)
        )

        guard let geo = engine.geometry(for: inputs, mode: .captionTheaterAspectFitTopPinned) else {
            Issue.record("Expected geometry.")
            return
        }

        let innerWidth = Double(1920 - 80 - 40)
        let innerHeight = Double(1080 - 10 - 90)
        #expect(abs(Double(geo.activePictureRect.width) - innerWidth) < 0.01)
        #expect(geo.activePictureRect.minX == 80)
        #expect(geo.activePictureRect.minY == 10)

        #expect(geo.captionReadingRect.minX == 80)
        #expect(abs(Double(geo.captionReadingRect.width) - innerWidth) < 0.01)

        let expectedPictureBottom = 10 + geo.activePictureRect.height
        #expect(abs(Double(geo.captionReadingRect.minY) - expectedPictureBottom) < 0.01)
        let expectedCaptionHeight = max(0, innerHeight - Double(geo.activePictureRect.height))
        #expect(abs(Double(geo.captionReadingRect.height) - expectedCaptionHeight) < 0.01)
    }

    /// Regression across representative container sizes (points): phone, tablet, TV, desktop-class window.
    @Test func heroTopPinPreservesAspectAcrossReferenceContainerSizes() {
        let aspect = 2.39
        let sizes: [CGSize] = [
            CGSize(width: 393, height: 852),
            CGSize(width: 1024, height: 1366),
            CGSize(width: 1920, height: 1080),
            CGSize(width: 1440, height: 900),
        ]

        for size in sizes {
            let inputs = CaptionTheaterLayoutInputs(
                containerSize: size,
                pictureAspectRatioWidthOverHeight: aspect
            )
            guard let geo = engine.geometry(for: inputs, mode: .captionTheaterAspectFitTopPinned) else {
                Issue.record("Expected geometry for container \(size.width)x\(size.height).")
                continue
            }

            let renderedAspect = Double(geo.activePictureRect.width / geo.activePictureRect.height)
            #expect(abs(renderedAspect - aspect) < 0.02)
            #expect(geo.captionReadingRect.minY >= geo.activePictureRect.maxY - 0.01)
            #expect(geo.captionReadingRect.height >= 0)
            #expect(geo.activePictureRect.maxX <= size.width + 0.01)
            #expect(geo.activePictureRect.maxY <= size.height + 0.01)
        }
    }
}
