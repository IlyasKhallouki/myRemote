import Foundation
import Network
import TVRemoteCore

enum TransportState {
    case idle
    case connecting
    case connected
    case failed(Error)
}

enum TransportError: LocalizedError {
    case notConnected
    case protocolFailure(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to a TV."
        case .protocolFailure(let message): message
        }
    }
}

struct VolumeState: Equatable, Sendable {
    let level: UInt64
    let max: UInt64
    let muted: Bool
}

struct DiscoveredTV: Identifiable, Equatable, Sendable {
    let serviceName: String
    let endpoint: NWEndpoint
    var host: String?
    var port: UInt16?

    var id: String { serviceName }

    static func == (lhs: DiscoveredTV, rhs: DiscoveredTV) -> Bool {
        lhs.serviceName == rhs.serviceName
            && lhs.host == rhs.host
            && lhs.port == rhs.port
    }
}

@MainActor
protocol TVTransport: AnyObject {
    var state: TransportState { get }
    var isSimulated: Bool { get }
    var volumeState: VolumeState? { get }

    /// Whether the socket is genuinely usable *right now*.
    ///
    /// Distinct from `state == .connected`, which is only our own last belief.
    /// When iOS suspends the app the socket dies without any callback running,
    /// so we come back believing we are connected, write into a dead connection
    /// and silently drop the key — the "green dot, nothing happens" failure.
    var isHealthy: Bool { get }

    /// Last thing the TV told us about itself. Drives the automations.
    var isOn: Bool { get }
    var currentApp: String { get }
    func connect(to tv: DiscoveredTV) async throws
    func send(_ key: RemoteKey) async throws
    func launch(_ appLink: String) async throws
    func sendText(_ text: String) async throws
    func sendKeyCode(_ code: UInt64) async throws
    func setVolume(level: UInt64) async throws
    var canType: Bool { get }
    func disconnect()
}
