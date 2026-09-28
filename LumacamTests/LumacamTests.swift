//
//  LumacamTests.swift
//  LumacamTests
//
//  Created by Jacob Goodman on 6/25/25.
//

import XCTest
@testable import Lumacam

final class LensPresetTests: XCTestCase {
    func testTripleCameraWithThreeTimesTelephoto() {
        let lenses = CameraCapabilities.lensPresets(minZoom: 0.5, maxZoom: 15, telephoto: 3)
        XCTAssertEqual(lenses, [0.5, 1, 2, 3])
    }

    func testTripleCameraWithFiveTimesTelephoto() {
        let lenses = CameraCapabilities.lensPresets(minZoom: 0.5, maxZoom: 25, telephoto: 5)
        XCTAssertEqual(lenses, [0.5, 1, 2, 5])
    }

    func testDualWideCameraGetsDigitalTwoTimes() {
        let lenses = CameraCapabilities.lensPresets(minZoom: 0.5, maxZoom: 10, telephoto: nil)
        XCTAssertEqual(lenses, [0.5, 1, 2])
    }

    func testTwoTimesTelephotoIsNotDuplicated() {
        let lenses = CameraCapabilities.lensPresets(minZoom: 1, maxZoom: 10, telephoto: 2)
        XCTAssertEqual(lenses, [1, 2])
    }

    func testSingleWideCamera() {
        let lenses = CameraCapabilities.lensPresets(minZoom: 1, maxZoom: 10, telephoto: nil)
        XCTAssertEqual(lenses, [1, 2])
    }
}

final class LensLabelTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(ZoomDial.label(for: 0.5), ".5")
        XCTAssertEqual(ZoomDial.label(for: 1), "1")
        XCTAssertEqual(ZoomDial.label(for: 1.26), "1.3")
        XCTAssertEqual(ZoomDial.label(for: 3), "3")
    }
}

final class LevelReadingTests: XCTestCase {
    private let accuracy = 0.0001

    func testUprightPortraitIsLevel() {
        let reading = LevelMonitor.reading(x: 0, y: -1, z: 0)
        XCTAssertEqual(reading.roll, 0, accuracy: accuracy)
        XCTAssertEqual(reading.deviation, 0, accuracy: accuracy)
        XCTAssertTrue(reading.isUpright)
    }

    func testSlightClockwiseTilt() {
        let angle = 5.0 * .pi / 180
        let reading = LevelMonitor.reading(x: sin(angle), y: -cos(angle), z: 0)
        XCTAssertEqual(reading.deviation, angle, accuracy: accuracy)
    }

    func testLandscapeMeasuresFromNearestQuarterTurn() {
        let angle = 90.0 * .pi / 180 - 3.0 * .pi / 180
        let reading = LevelMonitor.reading(x: sin(angle), y: -cos(angle), z: 0)
        XCTAssertEqual(reading.deviation, -3.0 * .pi / 180, accuracy: accuracy)
    }

    func testFlatPhoneIsNotUpright() {
        XCTAssertFalse(LevelMonitor.reading(x: 0, y: 0, z: -1).isUpright)
    }
}

final class SelfTimerTests: XCTestCase {
    @MainActor
    func testCyclesThroughOptions() {
        XCTAssertEqual(CameraViewModel.SelfTimer.off.next, .three)
        XCTAssertEqual(CameraViewModel.SelfTimer.three.next, .ten)
        XCTAssertEqual(CameraViewModel.SelfTimer.ten.next, .off)
    }
}

final class PhotoCropperTests: XCTestCase {
    func testLandscapeFourThreeToSixteenNine() {
        let rect = PhotoCropper.cropRect(width: 4032, height: 3024, ratio: PhotoAspect.sixteenNine.longToShortRatio)
        XCTAssertEqual(rect, CGRect(x: 0, y: 378, width: 4032, height: 2268))
    }

    func testPortraitFourThreeToSixteenNine() {
        let rect = PhotoCropper.cropRect(width: 3024, height: 4032, ratio: PhotoAspect.sixteenNine.longToShortRatio)
        XCTAssertEqual(rect, CGRect(x: 378, y: 0, width: 2268, height: 4032))
    }

    func testSquare() {
        let rect = PhotoCropper.cropRect(width: 4032, height: 3024, ratio: PhotoAspect.square.longToShortRatio)
        XCTAssertEqual(rect, CGRect(x: 504, y: 0, width: 3024, height: 3024))
    }

    func testMatchingRatioIsLeftAlone() {
        XCTAssertNil(PhotoCropper.cropRect(width: 4032, height: 3024, ratio: PhotoAspect.fourThree.longToShortRatio))
    }

    func testCropsEncodedImage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let cropped = try XCTUnwrap(PhotoCropper.crop(data, to: .sixteenNine))
        let result = try XCTUnwrap(UIImage(data: cropped))
        XCTAssertEqual(result.size.width * result.scale, 400)
        XCTAssertEqual(result.size.height * result.scale, 225)
    }
}
