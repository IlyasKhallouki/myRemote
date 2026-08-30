import Foundation

struct RemoteFeatures: OptionSet, Sendable {
    let rawValue: UInt64

    static let ping = RemoteFeatures(rawValue: 1 << 0)
    static let key = RemoteFeatures(rawValue: 1 << 1)
    static let ime = RemoteFeatures(rawValue: 1 << 2)
    static let voice = RemoteFeatures(rawValue: 1 << 3)
    static let power = RemoteFeatures(rawValue: 1 << 5)
    static let volume = RemoteFeatures(rawValue: 1 << 6)
    static let appLink = RemoteFeatures(rawValue: 1 << 9)

    static let clientSupported: RemoteFeatures = [.ping, .key, .ime, .power, .volume, .appLink]
}

enum IncomingMessage: Equatable {
    case configure(features: RemoteFeatures)
    case setActive
    case start(started: Bool)
    case pingRequest(value: UInt64)
    case volume(level: UInt64, max: UInt64, muted: Bool)
    case currentApp(String)
    case error(String)
    case unrecognised
}

enum RemoteCodec {
    private enum Field {
        static let configure = 1
        static let setActive = 2
        static let error = 3
        static let pingRequest = 8
        static let pingResponse = 9
        static let keyInject = 10
        static let imeKeyInject = 20
        static let start = 40
        static let setVolumeLevel = 50
        static let appLinkLaunch = 90
    }

    static let shortPress: UInt64 = 3

    static func parse(_ bytes: [UInt8]) -> IncomingMessage? {
        guard let message = ProtoMessage(decoding: bytes) else { return nil }

        if let configure = message[Field.configure]?.message {
            let raw = configure[1]?.uint ?? 0
            return .configure(features: RemoteFeatures(rawValue: raw))
        }
        if message[Field.setActive] != nil {
            return .setActive
        }
        if let ping = message[Field.pingRequest]?.message {
            return .pingRequest(value: ping[1]?.uint ?? 0)
        }
        if let start = message[Field.start]?.message {
            return .start(started: start[1]?.bool ?? false)
        }
        if let volume = message[Field.setVolumeLevel]?.message {
            return .volume(
                level: volume[7]?.uint ?? 0,
                max: volume[6]?.uint ?? 0,
                muted: volume[8]?.bool ?? false
            )
        }
        if let ime = message[Field.imeKeyInject]?.message {
            let package = ime[1]?.message?[12]?.string ?? ""
            return .currentApp(package)
        }
        if let error = message[Field.error]?.message {
            return .error(error[2]?.string ?? "unknown error")
        }
        return .unrecognised
    }

    static func configureReply(features: RemoteFeatures) -> [UInt8] {
        let deviceInfo = Protobuf.varintField(3, 1)
            + Protobuf.stringField(4, "1")
            + Protobuf.stringField(5, "atvremote")
            + Protobuf.stringField(6, "1.0.0")
        let configure = Protobuf.varintField(1, features.rawValue)
            + Protobuf.bytesField(2, deviceInfo)
        return Protobuf.bytesField(Field.configure, configure)
    }

    static func setActiveReply(features: RemoteFeatures) -> [UInt8] {
        Protobuf.bytesField(Field.setActive, Protobuf.varintField(1, features.rawValue))
    }

    static func pingReply(_ value: UInt64) -> [UInt8] {
        Protobuf.bytesField(Field.pingResponse, Protobuf.varintField(1, value))
    }

    static func keyInject(code: UInt64, direction: UInt64 = shortPress) -> [UInt8] {
        let inject = Protobuf.varintField(1, code) + Protobuf.varintField(2, direction)
        return Protobuf.bytesField(Field.keyInject, inject)
    }

    static func launchApp(_ link: String) -> [UInt8] {
        Protobuf.bytesField(Field.appLinkLaunch, Protobuf.stringField(1, link))
    }
}

extension RemoteKey {
    var androidKeyCode: UInt64 {
        switch self {
        case .up: 19
        case .down: 20
        case .left: 21
        case .right: 22
        case .ok: 23
        case .back: 4
        case .home: 3
        case .playPause: 85
        case .volumeUp: 24
        case .volumeDown: 25
        }
    }
}
