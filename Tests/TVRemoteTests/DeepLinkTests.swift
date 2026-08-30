import Foundation
import XCTest
@testable import TVRemote

final class DeepLinkTests: XCTestCase {
    private func parse(_ string: String) -> DeepLinkAction? {
        guard let url = URL(string: string) else { return nil }
        return DeepLink.parse(url)
    }

    func testKeyLinks() {
        XCTAssertEqual(parse("tvremote://key/playPause"), .key(.playPause))
        XCTAssertEqual(parse("tvremote://key/ok"), .key(.ok))
        XCTAssertEqual(parse("tvremote://key/volumeUp"), .key(.volumeUp))
    }

    func testKeyNamesAreForgiving() {
        XCTAssertEqual(parse("tvremote://key/play-pause"), .key(.playPause))
        XCTAssertEqual(parse("tvremote://key/PLAY_PAUSE"), .key(.playPause))
        XCTAssertEqual(parse("tvremote://key/Volume%20Up"), .key(.volumeUp))
    }

    func testMacroLinks() {
        XCTAssertEqual(parse("tvremote://macro/stream-pc"), .macro("stream-pc"))
        XCTAssertEqual(parse("tvremote://macro/movienight"), .macro("movie-night"))
        XCTAssertEqual(parse("tvremote://macro/Xbox"), .macro("xbox"))
    }

    func testEveryRemoteKeyIsAddressable() {
        for key in RemoteKey.allCases {
            XCTAssertEqual(parse("tvremote://key/\(key.rawValue)"), .key(key), "\(key.rawValue) unreachable")
        }
    }

    func testEveryMacroIsAddressable() {
        for macro in Macro.all {
            XCTAssertEqual(parse("tvremote://macro/\(macro.id)"), .macro(macro.id), "\(macro.id) unreachable")
        }
    }

    func testRejectsUnknownAndMalformed() {
        XCTAssertNil(parse("tvremote://key/frobnicate"))
        XCTAssertNil(parse("tvremote://macro/nope"))
        XCTAssertNil(parse("tvremote://key"))
        XCTAssertNil(parse("tvremote://"))
        XCTAssertNil(parse("otherapp://key/ok"))
        XCTAssertNil(parse("https://example.com/key/ok"))
    }

    func testSchemeIsCaseInsensitive() {
        XCTAssertEqual(parse("TVRemote://key/home"), .key(.home))
    }
}
