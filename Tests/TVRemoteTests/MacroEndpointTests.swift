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

    func testXboxSwitchesToHDMI1() {
        let xbox = Macro.all.first { $0.id == "xbox" }
        guard case let .keys(keys)? = xbox?.action else { return XCTFail("xbox should send keys") }
        XCTAssertEqual(keys, [.tvInputHDMI1])
        XCTAssertEqual(keys.first?.androidKeyCode, 243)
    }

    func testServerMacrosStillNeedABaseURL() {
        let streamPC = Macro.all.first { $0.id == "stream-pc" }!
        if case .server = streamPC.action {} else { XCTFail("stream-pc should be a server macro") }
        XCTAssertNil(streamPC.endpoint(base: ""))
    }

    func testExactlyOneAccentedMacro() {
        XCTAssertEqual(Macro.all.filter(\.accented).count, 1)
        XCTAssertEqual(Macro.all.first(where: \.accented)?.id, "stream-pc")
    }

    func testAllTenRemoteKeysExist() {
        XCTAssertEqual(RemoteKey.allCases.count, 11)
    }
}
