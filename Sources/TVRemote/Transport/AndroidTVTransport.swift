import Foundation
import Network
import Security
import TVRemoteCore

@MainActor
@Observable
final class AndroidTVTransport: TVTransport {
    let isSimulated = false

    private(set) var state: TransportState = .idle
    private(set) var isOn = false
    private(set) var currentApp = ""
    private(set) var volumeState: VolumeState?
    private var imeCounter: UInt64?
    private var fieldCounter: UInt64?

    static let sessionPort: UInt16 = 6466

    /// The TV pings us on its own schedule; going quiet for longer than this
    /// means the session is gone even if nothing reported an error.
    static let silenceTimeout: Duration = .seconds(45)

    var isHealthy: Bool {
        guard case .connected = state, connection != nil, isReady else { return false }
        return ContinuousClock.now - lastHeard < Self.silenceTimeout
    }

    private var connection: NWConnection?
    private var negotiated: RemoteFeatures = .clientSupported
    private var handshake: CheckedContinuation<Void, Error>?
    private var deadline: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    /// Mirrors the connection's readiness, updated from `stateUpdateHandler`.
    /// Reading `NWConnection.state` directly from a computed property means
    /// touching it off its own queue, which is not ours to do.
    private var isReady = false
    private var lastHeard = ContinuousClock.now
    private let queue = DispatchQueue(label: "app.lumind.tvremote.session")

    func connect(to tv: DiscoveredTV) async throws {
        disconnect()
        imeCounter = nil
        fieldCounter = nil
        TransportLog.shared.append("connect \(tv.serviceName) host=\(tv.host ?? "nil") port=\(tv.port.map(String.init) ?? "default")")
        guard let host = tv.host else {
            TransportLog.shared.append("connect ABORTED: endpoint never resolved to an address")
            throw TransportError.notConnected
        }

        let identity: SecIdentity
        do {
            identity = try Credentials.load()
        } catch {
            TransportLog.shared.append("connect ABORTED: credential — \(error.localizedDescription)")
            throw error
        }
        state = .connecting
        isReady = false
        lastHeard = .now

        let parameters = try NWParameters(tls: Self.tlsOptions(identity: identity), tcp: .init())
        let endpoint = NWEndpoint.hostPort(
            host: .init(host),
            port: .init(rawValue: tv.port ?? Self.sessionPort) ?? .init(integerLiteral: 6466)
        )
        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.handle(connectionState: state) }
        }
        connection.start(queue: queue)
        receiveLoop(on: connection)
        startDeadline(for: connection)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.handshake = continuation
            }
        } onCancel: {
            Task { @MainActor in self.finishHandshake(.failure(CancellationError())) }
        }
    }

    private func startDeadline(for connection: NWConnection) {
        deadline?.cancel()
        deadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self, !Task.isCancelled else { return }
            guard case .connecting = self.state else { return }
            // Say what actually went wrong. "The TV did not answer" is only
            // true when we could have reached it and it stayed quiet.
            let path = connection.currentPath
            if path?.unsatisfiedReason == .localNetworkDenied {
                self.fail(TransportError.protocolFailure("Local network permission is denied."))
            } else if path?.status != .satisfied {
                self.fail(TransportError.protocolFailure("No Wi-Fi connection."))
            } else {
                self.fail(TransportError.protocolFailure("The TV did not answer."))
            }
        }
    }

    func send(_ key: RemoteKey) async throws {
        guard isHealthy, let connection else {
            TransportLog.shared.append("send \(key.rawValue) REJECTED (not connected)")
            throw TransportError.notConnected
        }
        TransportLog.shared.append("send \(key.rawValue) (code \(key.androidKeyCode))")
        write(RemoteCodec.keyInject(code: key.androidKeyCode), on: connection)
    }

    /// True once the TV has told us which field has focus. Typing before that is ignored.
    var canType: Bool { imeCounter != nil && fieldCounter != nil }

    func sendText(_ text: String) async throws {
        guard isHealthy, let connection else { throw TransportError.notConnected }

        // Zero is a legitimate counter, not "unknown". Refusing to send until the
        // TV had volunteered a batch edit meant typing fell back to key events,
        // which this protocol does not deliver as text at all — so nothing was
        // typed. Verified against the panel: text lands with the counters at 0.
        let ime = imeCounter ?? 0
        let field = fieldCounter ?? 0
        TransportLog.shared.append("text \"\(text)\" (ime=\(ime) field=\(field))")
        write(RemoteCodec.textInput(text, imeCounter: ime, fieldCounter: field), on: connection)
    }

    func sendKeyCode(_ code: UInt64) async throws {
        guard isHealthy, let connection else { throw TransportError.notConnected }
        write(RemoteCodec.keyInject(code: code), on: connection)
    }

    func setVolume(level: UInt64) async throws {
        guard isHealthy, let connection else { throw TransportError.notConnected }
        TransportLog.shared.append("volume -> \(level) (experimental)")
        write(RemoteCodec.setVolume(level: level), on: connection)
    }

    func launch(_ appLink: String) async throws {
        guard isHealthy, let connection else { throw TransportError.notConnected }
        write(RemoteCodec.launchApp(appLink), on: connection)
    }

    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, case .connected = self.state else { return }
                guard !self.isHealthy else { continue }
                TransportLog.shared.append("watchdog: session went quiet, dropping it")
                self.fail(TransportError.protocolFailure("The TV stopped responding."))
                return
            }
        }
    }

    func disconnect() {
        watchdog?.cancel()
        watchdog = nil
        deadline?.cancel()
        deadline = nil
        connection?.cancel()
        connection = nil
        isReady = false
        finishHandshake(.failure(TransportError.notConnected))
        state = .idle
    }

    // MARK: - TLS

    nonisolated private static let tlsQueue = DispatchQueue(label: "app.lumind.tvremote.tls")

    /// `nonisolated` is load-bearing, not tidiness.
    ///
    /// This type is `@MainActor`, so a static method on it is main-actor
    /// isolated, and so is any closure written inside it — including the verify
    /// block below. But BoringSSL invokes that block on `tlsQueue`, off the main
    /// actor. Under Swift's strict executor checking that is a hard trap
    /// (`EXC_BREAKPOINT` in `swift_task_isCurrentExecutor`), which killed the app
    /// on every TLS handshake. The bug was always here; raising the deployment
    /// target to iOS 18 switched the runtime out of the legacy mode that used to
    /// let it slide.
    nonisolated private static func tlsOptions(identity: SecIdentity) throws -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        let security = options.securityProtocolOptions

        guard let secIdentity = sec_identity_create(identity) else {
            throw TransportError.protocolFailure("Stored credential could not be used for TLS.")
        }
        sec_protocol_options_set_local_identity(security, secIdentity)
        sec_protocol_options_set_min_tls_protocol_version(security, .TLSv12)

        // The TV presents a self-signed certificate; there is no CA to validate against.
        sec_protocol_options_set_verify_block(security, { @Sendable _, _, complete in
            complete(true)
        }, tlsQueue)

        return options
    }

    // MARK: - Framing

    private func receiveLoop(on connection: NWConnection) {
        let buffer = FrameBuffer()
        Self.pump(connection, buffer: buffer) { [self] frames in
            Task { @MainActor in
                for frame in frames { handle(frame: frame) }
            }
        } onEnd: { [self] error in
            Task { @MainActor in fail(error ?? TransportError.notConnected) }
        }
    }

    /// The read loop runs on the connection's own queue, so it must not be
    /// main-actor isolated. It previously recursed through a local function
    /// declared inside a `@MainActor` method, which is the same isolation
    /// mistake that made the TLS verify block trap — just one the compiler only
    /// warned about.
    nonisolated private static func pump(
        _ connection: NWConnection,
        buffer: FrameBuffer,
        onFrames: @escaping @Sendable ([[UInt8]]) -> Void,
        onEnd: @escaping @Sendable (Error?) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                onFrames(buffer.append(Array(data)))
            }
            if error != nil || isComplete {
                onEnd(error)
                return
            }
            pump(connection, buffer: buffer, onFrames: onFrames, onEnd: onEnd)
        }
    }

    private func write(_ payload: [UInt8], on connection: NWConnection) {
        let framed = Protobuf.lengthPrefixed(payload)
        connection.send(content: Data(framed), completion: .contentProcessed { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.fail(error) }
        })
    }

    // MARK: - Session state machine

    private func handle(frame: [UInt8]) {
        lastHeard = .now
        guard let connection, let message = RemoteCodec.parse(frame) else { return }

        switch message {
        case .configure(let serverFeatures):
            negotiated = RemoteFeatures(rawValue: RemoteFeatures.clientSupported.rawValue & serverFeatures.rawValue)
            write(RemoteCodec.configureReply(features: negotiated), on: connection)
        case .setActive:
            write(RemoteCodec.setActiveReply(features: negotiated), on: connection)
        case .pingRequest(let value):
            write(RemoteCodec.pingReply(value), on: connection)
        case .start(let started):
            deadline?.cancel()
            deadline = nil
            isOn = started
            TransportLog.shared.append("session started, tv is_on=\(started)")
            state = .connected
            startWatchdog()
            finishHandshake(.success(()))
        case .volume(let level, let max, let muted):
            volumeState = VolumeState(level: level, max: max, muted: muted)
        case .imeCounters(let ime, let field):
            imeCounter = ime
            fieldCounter = field
            TransportLog.shared.append("ime ready (ime=\(ime) field=\(field))")
        case .currentApp(let package):
            currentApp = package
            TransportLog.shared.append("current app: \(package)")
        case .error(let text):
            fail(TransportError.protocolFailure(text))
        case .unrecognised:
            break
        }
    }

    private func handle(connectionState: NWConnection.State) {
        switch connectionState {
        case .ready:
            isReady = true
        case .failed(let error):
            isReady = false
            fail(error)
        case .cancelled:
            isReady = false
            state = .idle
        case .waiting(let error):
            isReady = false
            // Transient: this is also the state while the local-network alert is on screen.
            // Network.framework retries by itself, so never fail here.
            let denied = connection?.currentPath?.unsatisfiedReason == .localNetworkDenied
            TransportLog.shared.append(denied ? "waiting: local network not granted yet" : "waiting: \(error)")
        default:
            break
        }
    }

    private func fail(_ error: Error) {
        watchdog?.cancel()
        watchdog = nil
        TransportLog.shared.append("failed: \(error.localizedDescription)")
        state = .failed(error)
        finishHandshake(.failure(error))
        connection?.cancel()
        connection = nil
    }

    private func finishHandshake(_ result: Result<Void, Error>) {
        guard let handshake else { return }
        self.handshake = nil
        handshake.resume(with: result)
    }
}

private final class FrameBuffer: @unchecked Sendable {
    private var bytes: [UInt8] = []
    private let lock = NSLock()

    func append(_ incoming: [UInt8]) -> [[UInt8]] {
        lock.lock()
        defer { lock.unlock() }
        bytes += incoming

        var frames: [[UInt8]] = []
        while true {
            guard let (length, width) = Protobuf.decodeVarint(bytes, at: 0) else { break }
            let end = width + Int(length)
            guard bytes.count >= end else { break }
            frames.append(Array(bytes[width..<end]))
            bytes.removeFirst(end)
        }
        return frames
    }
}
