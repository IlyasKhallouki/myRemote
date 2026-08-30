import Foundation
import XCTest
@testable import TVRemote

final class MacroEndpointTests: XCTestCase {
    func testEmptyBaseYieldsNoEndpoint() {
        XCTAssertNil(Macro.all[0].endpoint(base: ""))
        XCTAssertNil(Macro.all[0].endpoint(base: "   "))
    }

    func testEndpointBuiltFromBase() {
        XCTAssertEqual(
            Macro.all[0].endpoint(base: "http://192.168.1.10:8080")?.absoluteString,
            "http://192.168.1.10:8080/macro/stream-pc"
        )
    }

    func testTrailingSlashNotDoubled() {
        XCTAssertEqual(
            Macro.all[1].endpoint(base: "http://host:8080/")?.absoluteString,
            "http://host:8080/macro/xbox"
        )
    }

    func testExactlyOneAccentedMacro() {
        XCTAssertEqual(Macro.all.filter(\.accented).count, 1)
        XCTAssertEqual(Macro.all.first(where: \.accented)?.id, "stream-pc")
    }

    func testAllTenRemoteKeysExist() {
        XCTAssertEqual(RemoteKey.allCases.count, 10)
    }
}
