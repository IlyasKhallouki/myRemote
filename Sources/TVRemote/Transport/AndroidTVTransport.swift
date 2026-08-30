import Foundation
import Network
import Security

@MainActor
@Observable
final class AndroidTVTransport: TVTransport {
    let isSimulated = false

    private(set) var state: TransportState = .idle
    private(set) var isOn = false
    private(set) var currentApp = ""
    private(set) var volumeState: VolumeState?

    static let sessionPort: UInt16 = 6466

    private var connection: NWConnection?
    private var negotiated: RemoteFeatures = .clientSupported
    private var handshake: CheckedContinuation<Void, Error>?
    private var deadline: Task<Void, Never>?
    private let queue = DispatchQueue(label: "app.lumind.tvremote.session")

    func connect(to tv: DiscoveredTV) async throws {
        disconnect()
        guard let host = tv.host else { throw TransportError.notConnected }

        let identity = try Credentials.load()
        state = .connecting

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
            if connection.currentPath?.unsatisfiedReason == .localNetworkDenied {
                self.fail(TransportError.protocolFailure("Local network permission is denied."))
            } else {
                self.fail(TransportError.protocolFailure("The TV did not answer."))
            }
        }
    }

    func send(_ key: RemoteKey) async throws {
        guard case .connected = state, let connection else {
            TransportLog.shared.append("send \(key.rawValue) REJECTED (not connected)")
            throw TransportError.notConnected
        }
        TransportLog.shared.append("send \(key.rawValue) (code \(key.androidKeyCode))")
        write(RemoteCodec.keyInject(code: key.androidKeyCode), on: connection)
    }

    func launch(_ appLink: String) async throws {
        guard case .connected = state, let connection else { throw TransportError.notConnected }
        write(RemoteCodec.launchApp(appLink), on: connection)
    }

    func disconnect() {
        deadline?.cancel()
        deadline = nil
        connection?.cancel()
        connection = nil
        finishHandshake(.failure(TransportError.notConnected))
        state = .idle
    }

    // MARK: - TLS

    private static func tlsOptions(identity: SecIdentity) throws -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        let security = options.securityProtocolOptions

        guard let secIdentity = sec_identity_create(identity) else {
            throw TransportError.protocolFailure("Stored credential could not be used for TLS.")
        }
        sec_protocol_options_set_local_identity(security, secIdentity)
        sec_protocol_options_set_min_tls_protocol_version(security, .TLSv12)

        // The TV presents a self-signed certificate; there is no CA to validate against.
        sec_protocol_options_set_verify_block(security, { _, _, complete in
            complete(true)
        }, DispatchQueue(label: "app.lumind.tvremote.tls"))

        return options
    }

    // MARK: - Framing

    private func receiveLoop(on connection: NWConnection) {
        let buffer = FrameBuffer()
        func step() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, isComplete, error in
                if let data, !data.isEmpty {
                    let frames = buffer.append(Array(data))
                    Task { @MainActor in
                        for frame in frames { self.handle(frame: frame) }
                    }
                }
                if error != nil || isComplete {
                    Task { @MainActor in self.fail(error ?? TransportError.notConnected) }
                    return
                }
                step()
            }
        }
        step()
    }

    private func write(_ payload: [UInt8], on connection: NWConnection) {
        let framed = Protobuf.lengthPrefixed(payload)
        connection.send(content: Data(framed), completion: .contentProcessed { _ in })
    }

    // MARK: - Session state machine

    private func handle(frame: [UInt8]) {
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
            finishHandshake(.success(()))
        case .volume(let level, let max, let muted):
            volumeState = VolumeState(level: level, max: max, muted: muted)
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
        case .failed(let error):
            fail(error)
        case .cancelled:
            state = .idle
        case .waiting(let error):
            // Transient: this is also the state while the local-network alert is on screen.
            // Network.framework retries by itself, so never fail here.
            let denied = connection?.currentPath?.unsatisfiedReason == .localNetworkDenied
            TransportLog.shared.append(denied ? "waiting: local network not granted yet" : "waiting: \(error)")
        default:
            break
        }
    }

    private func fail(_ error: Error) {
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
