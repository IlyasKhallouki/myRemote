import Foundation
import Network

enum RemoteKey: String, CaseIterable, Sendable {
    case up, down, left, right, ok, back, home, playPause, volumeUp, volumeDown
}

enum TransportState {
    case idle
    case connecting
    case connected
    case failed(Error)
}

enum TransportError: LocalizedError {
    case notImplemented
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notImplemented: "The Android TV Remote protocol is not implemented yet."
        case .notConnected: "Not connected to a TV."
        }
    }
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
    func connect(to tv: DiscoveredTV) async throws
    func send(_ key: RemoteKey) async throws
    func disconnect()
}
