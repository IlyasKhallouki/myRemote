import Foundation
import XCTest
import TVRemoteCore
@testable import TVRemote

final class RemoteCodecTests: XCTestCase {
    private let negotiated = RemoteFeatures(rawValue: 615)

    func testClientFeatureSetMatchesReferenceImplementation() {
        XCTAssertEqual(RemoteFeatures.clientSupported.rawValue, 615)
    }

    func testConfigureReplyMatchesGoldenBytes() {
        XCTAssertEqual(RemoteCodec.configureReply(features: negotiated), [
            0x0A, 0x1C, 0x08, 0xE7, 0x04, 0x12, 0x17, 0x18, 0x01, 0x22, 0x01, 0x31,
            0x2A, 0x09, 0x61, 0x74, 0x76, 0x72, 0x65, 0x6D, 0x6F, 0x74, 0x65,
            0x32, 0x05, 0x31, 0x2E, 0x30, 0x2E, 0x30,
        ])
    }

    func testSetActiveReplyMatchesGoldenBytes() {
        XCTAssertEqual(RemoteCodec.setActiveReply(features: negotiated), [0x12, 0x03, 0x08, 0xE7, 0x04])
    }

    func testPingReplyMatchesGoldenBytes() {
        XCTAssertEqual(RemoteCodec.pingReply(42), [0x4A, 0x02, 0x08, 0x2A])
    }

    func testKeyInjectMatchesGoldenBytes() {
        XCTAssertEqual(RemoteCodec.keyInject(code: 23), [0x52, 0x04, 0x08, 0x17, 0x10, 0x03])
        XCTAssertEqual(RemoteCodec.keyInject(code: 24), [0x52, 0x04, 0x08, 0x18, 0x10, 0x03])
        XCTAssertEqual(RemoteCodec.keyInject(code: 243), [0x52, 0x05, 0x08, 0xF3, 0x01, 0x10, 0x03])
    }

    func testLaunchAppMatchesGoldenBytes() {
        let expected: [UInt8] = [0xD2, 0x05, 0x21, 0x0A, 0x1F] + Array("https://www.netflix.com/title/1".utf8)
        XCTAssertEqual(RemoteCodec.launchApp("https://www.netflix.com/title/1"), expected)
    }

    func testEveryRemoteKeyEncodesToItsAndroidCode() {
        let expected: [RemoteKey: UInt64] = [
            .up: 19, .down: 20, .left: 21, .right: 22, .ok: 23,
            .back: 4, .home: 3, .playPause: 85, .volumeUp: 24, .volumeDown: 25, .volumeMute: 164, .tvInputHDMI1: 243,
        ]
        for key in RemoteKey.allCases {
            XCTAssertEqual(key.androidKeyCode, expected[key], "\(key.rawValue)")
        }
    }

    func testDecodesPingRequest() {
        XCTAssertEqual(RemoteCodec.parse([0x42, 0x04, 0x08, 0x07, 0x10, 0x01]), .pingRequest(value: 7))
    }

    func testDecodesStart() {
        XCTAssertEqual(RemoteCodec.parse([0xC2, 0x02, 0x02, 0x08, 0x01]), .start(started: true))
    }

    func testDecodesVolume() {
        XCTAssertEqual(
            RemoteCodec.parse([0x92, 0x03, 0x04, 0x30, 0x64, 0x38, 0x0C]),
            .volume(level: 12, max: 100, muted: false)
        )
    }

    func testDecodesCurrentApp() {
        let bytes: [UInt8] = [0xA2, 0x01, 0x15, 0x0A, 0x13, 0x62, 0x11] + Array("com.netflix.ninja".utf8)
        XCTAssertEqual(RemoteCodec.parse(bytes), .currentApp("com.netflix.ninja"))
    }

    func testDecodesConfigureWithServerFeatures() {
        XCTAssertEqual(
            RemoteCodec.parse([0x0A, 0x03, 0x08, 0xEE, 0x04]),
            .configure(features: RemoteFeatures(rawValue: 622))
        )
    }

    func testVarintRoundTrip() {
        for value in [UInt64(0), 1, 127, 128, 300, 615, 16383, 16384, UInt64(UInt32.max)] {
            let encoded = Protobuf.varint(value)
            let decoded = Protobuf.decodeVarint(encoded, at: 0)
            XCTAssertEqual(decoded?.value, value, "varint \(value)")
            XCTAssertEqual(decoded?.width, encoded.count)
        }
    }

    func testRejectsTruncatedMessage() {
        XCTAssertNil(ProtoMessage(decoding: [0x0A, 0x10, 0x08]))
        XCTAssertNil(Protobuf.decodeVarint([0x80, 0x80], at: 0))
    }
}

extension RemoteCodecTests {
    func testTextInputMatchesGoldenBytes() {
        XCTAssertEqual(RemoteCodec.textInput("hello", imeCounter: 7, fieldCounter: 3), [
            0xAA, 0x01, 0x15, 0x08, 0x07, 0x10, 0x03, 0x1A, 0x0F, 0x08, 0x01, 0x12,
            0x0B, 0x08, 0x04, 0x10, 0x04, 0x1A, 0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F,
        ])
    }

    func testDecodesImeCounters() {
        XCTAssertEqual(RemoteCodec.parse([0xAA, 0x01, 0x04, 0x08, 0x07, 0x10, 0x03]),
                       .imeCounters(ime: 7, field: 3))
    }

    func testSingleCharacterDoesNotUnderflowTheCaret() {
        let bytes = RemoteCodec.textInput("a", imeCounter: 1, fieldCounter: 1)
        XCTAssertFalse(bytes.isEmpty)
    }
}

final class CharacterKeysTests: XCTestCase {
    func testLettersMapToTheAndroidRange() {
        XCTAssertEqual(CharacterKeys.code(for: "a"), 29)
        XCTAssertEqual(CharacterKeys.code(for: "z"), 54)
        XCTAssertEqual(CharacterKeys.code(for: "A"), 29, "case folds")
    }

    func testDigitsMapToTheAndroidRange() {
        XCTAssertEqual(CharacterKeys.code(for: "0"), 7)
        XCTAssertEqual(CharacterKeys.code(for: "9"), 16)
    }

    func testPunctuation() {
        XCTAssertEqual(CharacterKeys.code(for: " "), 62)
        XCTAssertEqual(CharacterKeys.code(for: "."), 56)
        XCTAssertEqual(CharacterKeys.code(for: "@"), 77)
    }

    func testEveryAlphanumericIsTypeable() {
        for character in "abcdefghijklmnopqrstuvwxyz0123456789" {
            XCTAssertNotNil(CharacterKeys.code(for: character), "\(character)")
        }
        XCTAssertTrue(CharacterKeys.unsupported(in: "breaking bad 2008").isEmpty)
    }

    func testUnsupportedCharactersAreReported() {
        XCTAssertEqual(CharacterKeys.unsupported(in: "hé"), ["é"])
    }
}
