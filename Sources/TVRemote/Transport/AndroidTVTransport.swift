// Milestone 2 fills this in by porting the pairing and session protocol from
// androidtvremote2: pairing on port 6467, session on 6466, self-signed client
// certificate, length-delimited protobuf framing. No speculative wire code here.

import Foundation

@MainActor
@Observable
final class AndroidTVTransport: TVTransport {
    let isSimulated = false

    private(set) var state: TransportState = .idle

    func connect(to tv: DiscoveredTV) async throws {
        throw TransportError.notImplemented
    }

    func send(_ key: RemoteKey) async throws {
        throw TransportError.notImplemented
    }

    func disconnect() {}
}
