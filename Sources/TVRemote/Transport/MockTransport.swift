import Foundation

struct TransportLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

@MainActor
@Observable
final class MockTransport: TVTransport {
    private(set) var state: TransportState = .idle
    private(set) var log: [TransportLogEntry] = []

    private let capacity = 200

    func connect(to tv: DiscoveredTV) async throws {
        state = .connecting
        let address = "\(tv.host ?? "unresolved"):\(tv.port.map(String.init) ?? "-")"
        append("connect \(tv.serviceName) at \(address)")
        state = .connected
    }

    func send(_ key: RemoteKey) async throws {
        guard case .connected = state else { throw TransportError.notConnected }
        append("send \(key.rawValue)")
    }

    func disconnect() {
        append("disconnect")
        state = .idle
    }

    private func append(_ message: String) {
        log.append(TransportLogEntry(timestamp: Date(), message: message))
        if log.count > capacity {
            log.removeFirst(log.count - capacity)
        }
    }
}
