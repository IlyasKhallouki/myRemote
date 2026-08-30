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
            "http://192.168.1.10:8080/macro/xbox"
        )
    }

    func testTrailingSlashNotDoubled() {
        XCTAssertEqual(
            Macro.all[1].endpoint(base: "http://host:8080/")?.absoluteString,
            "http://host:8080/macro/youtube"
        )
    }

    func testXboxUsesTheHDMI1PassthroughURI() {
        guard case let .launch(link)? = Macro.all.first(where: { $0.id == "xbox" })?.action else {
            return XCTFail("xbox should launch an input")
        }
        XCTAssertTrue(link.hasPrefix("content://android.media.tv/passthrough/"))
        XCTAssertTrue(link.contains("HW4"), "HW4 is hdmi_port 1 on this panel")
    }

    func testNoMacroUsesABarePackageName() {
        for macro in Macro.all {
            guard case let .launch(link) = macro.action else { continue }
            XCTAssertTrue(link.contains("://"), "\(macro.id): a bare package name does not launch")
        }
    }

    func testAppMacrosLaunchByURI() {
        for (id, expected) in [("xbox", AppLinks.hdmi1), ("youtube", AppLinks.youTube), ("spotify", AppLinks.spotify)] {
            guard case let .launch(package)? = Macro.all.first(where: { $0.id == id })?.action else {
                return XCTFail("\(id) should launch an app")
            }
            XCTAssertEqual(package, expected)
        }
    }

    func testExactlyOneAccentedMacro() {
        XCTAssertEqual(Macro.all.filter(\.accented).count, 1)
        XCTAssertEqual(Macro.all.first(where: \.accented)?.id, "xbox")
    }

    func testAllTenRemoteKeysExist() {
        XCTAssertEqual(RemoteKey.allCases.count, 12)
    }
}
