import Foundation

struct TransportLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

@MainActor
@Observable
final class TransportLog {
    static let shared = TransportLog()

    private(set) var entries: [TransportLogEntry] = []
    private let capacity = 200

    func append(_ message: String) {
        entries.append(TransportLogEntry(timestamp: Date(), message: message))
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }
}
