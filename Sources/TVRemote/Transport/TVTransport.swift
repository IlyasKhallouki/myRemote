import Foundation
import Network

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
    func connect(to tv: DiscoveredTV) async throws
    func send(_ key: RemoteKey) async throws
    func launch(_ appLink: String) async throws
    func sendText(_ text: String) async throws
    var canType: Bool { get }
    func disconnect()
}
