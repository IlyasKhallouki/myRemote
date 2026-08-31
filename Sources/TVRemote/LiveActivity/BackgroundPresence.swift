import Foundation
import TVRemoteCore

/// Refcounts the reasons to keep the app's process running.
///
/// Both the Lock Screen session and the TV watcher need the app awake, and they
/// come and go independently — whoever leaves last turns the lights off. Holding
/// the process is the expensive part of this app, so it is worth being strict
/// about who is asking and why.
@MainActor
@Observable
final class BackgroundPresence {
    static let shared = BackgroundPresence()

    enum Holder: String, CaseIterable {
        case lockScreen
        case tvWatcher
    }

    private let keepAlive = AudioKeepAlive()
    private(set) var holders: Set<Holder> = []

    var isRunning: Bool { keepAlive.isRunning }
    var lastFailure: String? { keepAlive.lastFailure }

    func hold(_ holder: Holder) {
        guard holders.insert(holder).inserted else { return }
        sync()
    }

    func release(_ holder: Holder) {
        guard holders.remove(holder) != nil else { return }
        sync()
    }

    private func sync() {
        if holders.isEmpty {
            keepAlive.stop()
        } else {
            keepAlive.start()
        }
    }
}
