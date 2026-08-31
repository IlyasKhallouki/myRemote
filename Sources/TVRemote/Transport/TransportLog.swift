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

    private static let previousRunKey = "transportLog.previousRun"

    private(set) var entries: [TransportLogEntry] = []

    /// What the last run managed to log before it ended. A crash takes the
    /// in-memory log with it, which is precisely when you most want to know how
    /// far things got, so it is mirrored to disk as it is written.
    private(set) var previousRun: [String] = []

    private let capacity = 200
    private let persistedCapacity = 80

    init() {
        previousRun = UserDefaults.standard.stringArray(forKey: Self.previousRunKey) ?? []
        UserDefaults.standard.removeObject(forKey: Self.previousRunKey)
    }

    func append(_ message: String) {
        entries.append(TransportLogEntry(timestamp: Date(), message: message))
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
        persist()
    }

    private func persist() {
        let tail = entries.suffix(persistedCapacity).map(\.message)
        UserDefaults.standard.set(tail, forKey: Self.previousRunKey)
    }
}
