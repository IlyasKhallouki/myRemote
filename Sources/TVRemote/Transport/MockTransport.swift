import Foundation

@MainActor
@Observable
final class MockTransport: TVTransport {
    let isSimulated = true
    private(set) var volumeState: VolumeState?

    private(set) var state: TransportState = .idle

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

    func launch(_ appLink: String) async throws {
        guard case .connected = state else { throw TransportError.notConnected }
        append("launch \(appLink)")
    }

    func disconnect() {
        append("disconnect")
        state = .idle
    }

    private func append(_ message: String) {
        TransportLog.shared.append(message)
    }
}
