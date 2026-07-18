//
//  MacWindowAspectPresetTests.swift
//  CaptionTheaterTests
//
//  Covers pure aspect-preset math used by the native macOS target.
//

import CoreGraphics
import XCTest
@testable import CaptionTheater

final class MacWindowAspectPresetTests: XCTestCase {

    func testSixteenByNinePresetPreservesRequestedRatio() {
        let size = MacWindowAspectPreset.sixteenByNine.contentSize(
            fitting: CGSize(width: 1280, height: 900),
            sourceAspect: nil
        )

        XCTAssertEqual(size.width / size.height, 16.0 / 9.0, accuracy: 0.001)
    }

    func testSourceAspectPresetUsesProvidedRatio() {
        let size = MacWindowAspectPreset.sourceAspect.contentSize(
            fitting: CGSize(width: 1200, height: 800),
            sourceAspect: 2.39
        )

        XCTAssertEqual(size.width / size.height, 2.39, accuracy: 0.001)
    }

    func testFreeformPresetLeavesSizeUnchanged() {
        let original = CGSize(width: 1111, height: 777)
        let size = MacWindowAspectPreset.freeform.contentSize(fitting: original, sourceAspect: 2.39)

        XCTAssertEqual(size, original)
    }
}

