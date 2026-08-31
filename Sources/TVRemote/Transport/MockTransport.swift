import Foundation
import TVRemoteCore

@MainActor
@Observable
final class MockTransport: TVTransport {
    let isSimulated = true
    private(set) var volumeState: VolumeState?

    private(set) var state: TransportState = .idle
    private(set) var isOn = true
    private(set) var currentApp = ""

    var isHealthy: Bool {
        if case .connected = state { return true }
        return false
    }

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

    func setVolume(level: UInt64) async throws {
        guard case .connected = state else { throw TransportError.notConnected }
        append("volume -> \(level)")
    }

    func launch(_ appLink: String) async throws {
        guard case .connected = state else { throw TransportError.notConnected }
        append("launch \(appLink)")
    }

    var canType: Bool { true }

    func sendText(_ text: String) async throws {
        guard case .connected = state else { throw TransportError.notConnected }
        append("text \"\(text)\"")
    }

    func sendKeyCode(_ code: UInt64) async throws {
        guard case .connected = state else { throw TransportError.notConnected }
        append("keycode \(code)")
    }

    func disconnect() {
        append("disconnect")
        state = .idle
    }

    private func append(_ message: String) {
        TransportLog.shared.append(message)
    }
}
