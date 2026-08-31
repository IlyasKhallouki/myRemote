import Foundation
import Network

/// Whether there is a network the TV could possibly be on.
///
/// Without this the app spends twelve seconds timing out and then blames the TV
/// — "The TV did not answer" — when the real answer is that the phone is on
/// cellular. It also stops the automation loop retrying a connection that
/// cannot succeed.
@MainActor
@Observable
final class NetworkReachability {
    static let shared = NetworkReachability()

    /// Starts optimistic: the monitor takes a moment to report, and refusing to
    /// connect during that window would be worse than trying and failing.
    private(set) var hasLocalNetwork = true

    /// Human-readable path state, for the Debug screen.
    private(set) var summary = "not started"

    private let monitor = NWPathMonitor()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { path in
            // Deliberately permissive: refuse only when there is provably no
            // local path, because a VPN reports interface type .other rather
            // than .wifi and being wrong here blocks the app entirely. Trying
            // and failing is a much cheaper mistake than refusing to try.
            let cellularOnly = path.usesInterfaceType(.cellular)
                && !path.usesInterfaceType(.wifi)
                && !path.usesInterfaceType(.wiredEthernet)
                && !path.usesInterfaceType(.other)
            let local = path.status == .satisfied && !cellularOnly
            let interfaces = [
                (NWInterface.InterfaceType.wifi, "wifi"),
                (.wiredEthernet, "wired"),
                (.cellular, "cellular"),
                (.other, "other"),
            ].filter { path.usesInterfaceType($0.0) }.map(\.1)
            let described = "\(path.status) [\(interfaces.joined(separator: ", "))]"

            Task { @MainActor in
                NetworkReachability.shared.hasLocalNetwork = local
                NetworkReachability.shared.summary = described
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.lumind.tvremote.path"))
    }
}
