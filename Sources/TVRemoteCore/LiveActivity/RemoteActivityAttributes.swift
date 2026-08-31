import ActivityKit
import Foundation

/// The Live Activity that puts the remote on the Lock Screen.
///
/// `ContentState` is the only thing that crosses into the widget process, so it
/// carries everything the Lock Screen needs to draw itself — the widget never
/// touches the transport.
public struct RemoteActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var tvName: String
        public var connection: Connection
        public var simulated: Bool
        public var volume: Volume?
        /// Set when a key press failed, so the Lock Screen can say why.
        public var detail: String?

        /// Proof of life for the buttons. Every intent that actually reaches the
        /// app process stamps this, so if it never changes when you tap, the tap
        /// is not being dispatched at all — which is a different bug from the key
        /// being sent and the TV ignoring it.
        public var lastAction: String?

        /// Keys to show instead of the launch macros, as `RemoteKey` raw values.
        /// Resolved app-side so the widget never has to know about preferences.
        public var contextKeys: [String]

        /// Foreground app on the TV, for the header.
        public var appName: String?

        /// Whether to offer a power key. Off unless the TV is known to take one.
        public var showsPower: Bool

        public init(
            tvName: String = "No TV",
            connection: Connection = .offline,
            simulated: Bool = false,
            volume: Volume? = nil,
            detail: String? = nil,
            lastAction: String? = nil,
            contextKeys: [String] = [],
            appName: String? = nil,
            showsPower: Bool = false
        ) {
            self.tvName = tvName
            self.connection = connection
            self.simulated = simulated
            self.volume = volume
            self.detail = detail
            self.lastAction = lastAction
            self.contextKeys = contextKeys
            self.appName = appName
            self.showsPower = showsPower
        }

        /// Written by hand so that a Live Activity started by an older build --
        /// whose stored state predates these fields -- still decodes instead of
        /// throwing when the app adopts it after an update.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tvName = try container.decodeIfPresent(String.self, forKey: .tvName) ?? "No TV"
            connection = try container.decodeIfPresent(Connection.self, forKey: .connection) ?? .offline
            simulated = try container.decodeIfPresent(Bool.self, forKey: .simulated) ?? false
            volume = try container.decodeIfPresent(Volume.self, forKey: .volume)
            detail = try container.decodeIfPresent(String.self, forKey: .detail)
            lastAction = try container.decodeIfPresent(String.self, forKey: .lastAction)
            contextKeys = try container.decodeIfPresent([String].self, forKey: .contextKeys) ?? []
            appName = try container.decodeIfPresent(String.self, forKey: .appName)
            showsPower = try container.decodeIfPresent(Bool.self, forKey: .showsPower) ?? false
        }
    }

    public enum Connection: String, Codable, Hashable, Sendable {
        case offline
        case connecting
        case live
    }

    public struct Volume: Codable, Hashable, Sendable {
        public var level: Int
        public var max: Int
        public var muted: Bool

        public init(level: Int, max: Int, muted: Bool) {
            self.level = level
            self.max = max
            self.muted = muted
        }

        public var fraction: Double {
            guard max > 0 else { return 0 }
            return Swift.min(1, Swift.max(0, Double(level) / Double(max)))
        }
    }

    public init() {}
}
