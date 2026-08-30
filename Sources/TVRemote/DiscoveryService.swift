import Foundation
import Network

enum DiscoveryState: Equatable {
    case idle
    case browsing
    case permissionDenied
    case failed(String)
}

@MainActor
@Observable
final class DiscoveryService {
    static let serviceType = "_androidtvremote2._tcp"
    static let domain = "local."
    static let lastKnownDefaultsKey = "lastKnownServiceName"

    private(set) var state: DiscoveryState = .idle
    private(set) var televisions: [DiscoveredTV] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "app.lumind.tvremote.discovery")
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastKnownServiceName: String? {
        get { defaults.string(forKey: Self.lastKnownDefaultsKey) }
        set { defaults.set(newValue, forKey: Self.lastKnownDefaultsKey) }
    }

    func start() {
        guard browser == nil else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.serviceType, domain: Self.domain)
        let browser = NWBrowser(for: descriptor, using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.handle(browserState: state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.handle(results: results) }
        }

        self.browser = browser
        state = .browsing
        browser.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        state = .idle
    }

    func remember(_ tv: DiscoveredTV) {
        lastKnownServiceName = tv.serviceName
    }

    static func serviceName(from endpoint: NWEndpoint) -> String? {
        if case let .service(name, _, _, _) = endpoint { return name }
        return nil
    }

    static func isPermissionDenied(_ error: NWError) -> Bool {
        if case let .dns(code) = error {
            return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied)
        }
        return false
    }

    func endpoint(forServiceNamed name: String) -> NWEndpoint {
        .service(name: name, type: Self.serviceType, domain: Self.domain, interface: nil)
    }

    func resolve(_ endpoint: NWEndpoint, timeout: Duration = .seconds(1)) async -> DiscoveredTV? {
        guard let name = Self.serviceName(from: endpoint) else { return nil }
        let connection = NWConnection(to: endpoint, using: .tcp)

        let resolved: (host: String, port: UInt16)? = await withTaskGroup(returning: (host: String, port: UInt16)?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    let box = ResumeOnce(continuation)
                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            box.resume(with: Self.remoteAddress(of: connection))
                        case .failed, .cancelled:
                            box.resume(with: nil)
                        default:
                            break
                        }
                    }
                    connection.start(queue: self.queue)
                }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        connection.cancel()
        guard let resolved else { return nil }
        return DiscoveredTV(serviceName: name, endpoint: endpoint, host: resolved.host, port: resolved.port)
    }

    private static func remoteAddress(of connection: NWConnection) -> (host: String, port: UInt16)? {
        guard let remote = connection.currentPath?.remoteEndpoint,
              case let .hostPort(host, port) = remote else { return nil }
        return (Self.describe(host), port.rawValue)
    }

    private static func describe(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .name(let name, _): name
        case .ipv4(let address): "\(address)".components(separatedBy: "%").first ?? "\(address)"
        case .ipv6(let address): "\(address)".components(separatedBy: "%").first ?? "\(address)"
        @unknown default: "\(host)"
        }
    }

    private func handle(browserState: NWBrowser.State) {
        switch browserState {
        case .ready:
            state = .browsing
        case .waiting(let error):
            state = Self.isPermissionDenied(error) ? .permissionDenied : .browsing
        case .failed(let error):
            state = Self.isPermissionDenied(error) ? .permissionDenied : .failed(error.localizedDescription)
        case .cancelled:
            state = .idle
        default:
            break
        }
    }

    private func handle(results: Set<NWBrowser.Result>) {
        let found = results.compactMap { result -> DiscoveredTV? in
            guard let name = Self.serviceName(from: result.endpoint) else { return nil }
            return DiscoveredTV(serviceName: name, endpoint: result.endpoint, host: nil, port: nil)
        }
        televisions = found.sorted { $0.serviceName < $1.serviceName }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private var continuation: CheckedContinuation<(host: String, port: UInt16)?, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<(host: String, port: UInt16)?, Never>) {
        self.continuation = continuation
    }

    func resume(with value: (host: String, port: UInt16)?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
