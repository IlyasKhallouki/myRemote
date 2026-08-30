import Foundation

@MainActor
@Observable
final class RemoteController {
    let discovery: DiscoveryService
    let transport: TVTransport

    private(set) var connectedTV: DiscoveredTV?

    init(transport: TVTransport = AndroidTVTransport(), discovery: DiscoveryService = DiscoveryService()) {
        self.transport = transport
        self.discovery = discovery
    }

    var mockTransport: MockTransport? { transport as? MockTransport }

    var statusTitle: String {
        if case let .failed(error) = transport.state {
            return (error as? LocalizedError)?.errorDescription ?? "Connection failed"
        }
        if let connectedTV { return connectedTV.serviceName }
        switch discovery.state {
        case .permissionDenied: return "Local network denied"
        case .failed: return "Discovery failed"
        case .browsing: return discovery.televisions.first?.serviceName ?? "Searching…"
        case .idle: return "No TV"
        }
    }

    func onForeground() {
        discovery.start()
        Task { await connectToBestAvailable() }
    }

    func onBackground() {
        discovery.stop()
    }

    func connectToBestAvailable() async {
        guard connectedTV == nil else { return }

        let remembered = discovery.lastKnownServiceName
        let winner = await withTaskGroup(of: DiscoveredTV?.self) { group in
            if let remembered {
                group.addTask { [discovery] in
                    let endpoint = await discovery.endpoint(forServiceNamed: remembered)
                    return await discovery.resolve(endpoint, timeout: .seconds(1))
                }
            }
            group.addTask { [weak self] in
                guard let self else { return nil }
                guard let candidate = await self.firstBrowseResult(timeout: .seconds(5)) else { return nil }
                return await self.discovery.resolve(candidate.endpoint, timeout: .seconds(3))
            }

            var result: DiscoveredTV?
            for await candidate in group where candidate != nil {
                result = candidate
                break
            }
            group.cancelAll()
            return result
        }

        guard let winner else { return }
        await connect(to: winner)
    }

    func connect(to tv: DiscoveredTV) async {
        do {
            try await transport.connect(to: tv)
            connectedTV = tv
            discovery.remember(tv)
        } catch {
            connectedTV = nil
        }
    }

    func send(_ key: RemoteKey) {
        Task { try? await transport.send(key) }
    }

    func perform(_ key: RemoteKey) async {
        if connectedTV == nil { await connectToBestAvailable() }
        try? await transport.send(key)
    }

    private func firstBrowseResult(timeout: Duration) async -> DiscoveredTV? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let first = discovery.televisions.first { return first }
            if Task.isCancelled { return nil }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }
}
