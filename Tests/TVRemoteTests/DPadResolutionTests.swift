import CoreGraphics
import XCTest
@testable import TVRemote

final class DPadResolutionTests: XCTestCase {
    func testBelowThresholdResolvesToNothing() {
        XCTAssertNil(DPadResolution.direction(for: CGSize(width: 0, height: 0)))
        XCTAssertNil(DPadResolution.direction(for: CGSize(width: 23, height: 23)))
        XCTAssertNil(DPadResolution.direction(for: CGSize(width: -23, height: 12)))
    }

    func testExactThresholdFires() {
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 24, height: 0)), .right)
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 0, height: -24)), .up)
    }

    func testDominantAxisWins() {
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 60, height: 20)), .right)
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: -60, height: 20)), .left)
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 20, height: 60)), .down)
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 20, height: -60)), .up)
    }

    func testDiagonalTieFavoursHorizontal() {
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 40, height: 40)), .right)
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: -40, height: -40)), .left)
    }

    func testVerticalSignMapsToScreenSpace() {
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 0, height: 100)), .down)
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 0, height: -100)), .up)
    }

    func testCustomThreshold() {
        XCTAssertNil(DPadResolution.direction(for: CGSize(width: 30, height: 0), threshold: 50))
        XCTAssertEqual(DPadResolution.direction(for: CGSize(width: 60, height: 0), threshold: 50), .right)
    }
}
