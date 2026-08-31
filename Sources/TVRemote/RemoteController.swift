import Foundation
import Network
import TVRemoteCore

@MainActor
@Observable
final class RemoteController {
    /// One controller per process. The Lock Screen intents run in this same
    /// process but outside any view, so they need a well-known instance to reach —
    /// and it has to be the same socket the UI is using.
    static let shared = RemoteController()

    let discovery: DiscoveryService
    let transport: TVTransport

    private(set) var connectedTV: DiscoveredTV?

    private var connecting: Task<Void, Never>?

    /// Set while the Lock Screen remote is up. Backgrounding must not tear the
    /// session down then: the whole point is that the socket survives.
    var holdsConnection = false

    /// Why the last send failed, surfaced on the Lock Screen where there is no
    /// other way to tell the user that nothing happened.
    private(set) var lastFailure: String?

    init(transport: TVTransport = AndroidTVTransport(), discovery: DiscoveryService = DiscoveryService()) {
        self.transport = transport
        self.discovery = discovery
    }

    /// Asks the socket, not our own last belief — see `TVTransport.isHealthy`.
    var isLive: Bool { transport.isHealthy }

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
        if !NetworkReachability.shared.hasLocalNetwork { return "Not on Wi-Fi" }
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
        NetworkReachability.shared.start()
        discovery.start()
        Task { await ensureLive() }
    }

    func onBackground() {
        discovery.stop()
        guard !holdsConnection else { return }
        transport.disconnect()
        connectedTV = nil
    }

    /// Reconnects when the socket has died, which iOS does to us on every backgrounding.
    ///
    /// Serialised: the automation loop and the UI both call this, and two
    /// handshakes in flight at once fight over a single continuation and tear
    /// down each other's connection.
    func ensureLive() async {
        guard !isLive else { return }
        if let connecting {
            await connecting.value
            return
        }
        let attempt = Task { @MainActor in await self.attemptConnection() }
        connecting = attempt
        await attempt.value
        connecting = nil
    }

    private func attemptConnection() async {
        connectedTV = nil

        // Nothing on cellular can reach the TV. Failing immediately beats a
        // twelve-second timeout that then blames the TV for not answering.
        guard NetworkReachability.shared.hasLocalNetwork else {
            lastFailure = "Not on Wi-Fi."
            return
        }

        // A manually configured address wins: the user told us where the TV is,
        // so there is nothing to discover.
        let manual = Preferences.shared.manualHost.trimmingCharacters(in: .whitespaces)
        if !manual.isEmpty {
            let host = NWEndpoint.Host(manual)
            let port = NWEndpoint.Port(rawValue: AndroidTVTransport.sessionPort) ?? .any
            await connect(to: DiscoveredTV(
                serviceName: manual,
                endpoint: .hostPort(host: host, port: port),
                host: manual,
                port: AndroidTVTransport.sessionPort
            ))
            if isLive { return }
        }

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
            lastFailure = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    func send(_ key: RemoteKey) {
        Task { await perform(key) }
    }

    @discardableResult
    func perform(_ key: RemoteKey) async -> Bool {
        await ensureLive()
        do {
            try await transport.send(key)
            lastFailure = nil
            return true
        } catch {
            lastFailure = (error as? LocalizedError)?.errorDescription ?? "Send failed"
            return false
        }
    }

    @discardableResult
    func launch(_ appLink: String) async -> Bool {
        await ensureLive()
        do {
            try await transport.launch(appLink)
            lastFailure = nil
            return true
        } catch {
            lastFailure = (error as? LocalizedError)?.errorDescription ?? "Launch failed"
            return false
        }
    }

    @discardableResult
    func setVolume(level: UInt64) async -> Bool {
        await ensureLive()
        do {
            try await transport.setVolume(level: level)
            lastFailure = nil
            return true
        } catch {
            lastFailure = (error as? LocalizedError)?.errorDescription ?? "Volume failed"
            return false
        }
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
