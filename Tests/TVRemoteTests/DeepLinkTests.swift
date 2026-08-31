import Foundation
import XCTest
import TVRemoteCore
@testable import TVRemote

final class DeepLinkTests: XCTestCase {
    private func parse(_ string: String) -> DeepLinkAction? {
        guard let url = URL(string: string) else { return nil }
        return DeepLink.parse(url)
    }

    func testKeyLinks() {
        XCTAssertEqual(parse("lumindtv://key/playPause"), .key(.playPause))
        XCTAssertEqual(parse("lumindtv://key/ok"), .key(.ok))
        XCTAssertEqual(parse("lumindtv://key/volumeUp"), .key(.volumeUp))
    }

    func testKeyNamesAreForgiving() {
        XCTAssertEqual(parse("lumindtv://key/play-pause"), .key(.playPause))
        XCTAssertEqual(parse("lumindtv://key/PLAY_PAUSE"), .key(.playPause))
        XCTAssertEqual(parse("lumindtv://key/Volume%20Up"), .key(.volumeUp))
    }

    func testMacroLinks() {
        XCTAssertEqual(parse("lumindtv://macro/xbox"), .macro("xbox"))
        XCTAssertEqual(parse("lumindtv://macro/YouTube"), .macro("youtube"))
        XCTAssertEqual(parse("lumindtv://macro/keyboard"), .macro("keyboard"))
    }

    func testEveryRemoteKeyIsAddressable() {
        for key in RemoteKey.allCases {
            XCTAssertEqual(parse("lumindtv://key/\(key.rawValue)"), .key(key), "\(key.rawValue) unreachable")
        }
    }

    func testEveryMacroIsAddressable() {
        for macro in Macro.all {
            XCTAssertEqual(parse("lumindtv://macro/\(macro.id)"), .macro(macro.id), "\(macro.id) unreachable")
        }
    }

    func testRejectsUnknownAndMalformed() {
        XCTAssertNil(parse("lumindtv://key/frobnicate"))
        XCTAssertNil(parse("lumindtv://macro/nope"))
        XCTAssertNil(parse("lumindtv://key"))
        XCTAssertNil(parse("lumindtv://"))
        XCTAssertNil(parse("otherapp://key/ok"))
        XCTAssertNil(parse("tvremote://key/ok"))
        XCTAssertNil(parse("https://example.com/key/ok"))
    }

    func testSchemeIsCaseInsensitive() {
        XCTAssertEqual(parse("LumindTV://key/home"), .key(.home))
    }
}
