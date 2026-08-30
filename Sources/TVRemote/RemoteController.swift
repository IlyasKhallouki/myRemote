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

    var isLive: Bool {
        if case .connected = transport.state { return true }
        return false
    }

    private var cachedAddress: (host: String, port: UInt16)? {
        get {
            let defaults = UserDefaults.standard
            guard let host = defaults.string(forKey: "lastKnownHost") else { return nil }
            let port = UInt16(defaults.integer(forKey: "lastKnownPort"))
            return (host, port == 0 ? AndroidTVTransport.sessionPort : port)
        }
        set {
            UserDefaults.standard.set(newValue?.host, forKey: "lastKnownHost")
            UserDefaults.standard.set(Int(newValue?.port ?? 0), forKey: "lastKnownPort")
        }
    }

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
        Task { await ensureLive() }
    }

    func onBackground() {
        discovery.stop()
        transport.disconnect()
        connectedTV = nil
    }

    /// Reconnects when the socket has died, which iOS does to us on every backgrounding.
    func ensureLive() async {
        guard !isLive else { return }
        connectedTV = nil

        if let cached = cachedAddress,
           let name = discovery.lastKnownServiceName {
            let candidate = DiscoveredTV(
                serviceName: name,
                endpoint: discovery.endpoint(forServiceNamed: name),
                host: cached.host,
                port: cached.port
            )
            await connect(to: candidate)
            if isLive { return }
        }

        await connectToBestAvailable()
    }

    func connectToBestAvailable() async {
        guard !isLive else { return }

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
            if let host = tv.host { cachedAddress = (host, tv.port ?? AndroidTVTransport.sessionPort) }
        } catch {
            connectedTV = nil
        }
    }

    func send(_ key: RemoteKey) {
        Task { await perform(key) }
    }

    func perform(_ key: RemoteKey) async {
        await ensureLive()
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
