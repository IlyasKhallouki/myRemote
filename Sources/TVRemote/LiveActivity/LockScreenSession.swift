// `Activity` is a plain non-final class with no `Sendable` conformance, so under
// Swift 6 strict concurrency every `update`/`end` call from this @MainActor class
// trips the sending-risks-data-races check. The handle is safe to use from any
// context — it is a thin proxy onto the ActivityKit daemon.
@preconcurrency import ActivityKit
import Foundation
import TVRemoteCore

/// Owns the Lock Screen remote: the Live Activity, the process keep-alive, and
/// mirroring transport state into the widget.
@MainActor
@Observable
final class LockScreenSession {
    static let shared = LockScreenSession()

    private(set) var isActive = false
    private(set) var lastError: String?

    private var activity: Activity<RemoteActivityAttributes>?
    private var mirror: Task<Void, Never>?
    private var pushed: RemoteActivityAttributes.ContentState?

    /// Last intent that reached this process, with a counter so repeats of the
    /// same key still read as a change on the card.
    private var lastAction: String?
    private var actionCount = 0

    private var controller: RemoteController { .shared }

    /// False when the user has switched Live Activities off for the app in Settings.
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func toggle() async {
        if isActive {
            await stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard !isActive else { return }
        guard isSupported else {
            lastError = "Live Activities are off for this app in Settings."
            return
        }

        // Take the connection off the backgrounding teardown path before anything
        // else, so the handoff to the Lock Screen never drops the socket.
        controller.holdsConnection = true
        BackgroundPresence.shared.hold(.lockScreen)
        await controller.ensureLive()

        do {
            activity = try Activity.request(
                attributes: RemoteActivityAttributes(),
                content: ActivityContent(state: snapshot(), staleDate: nil)
            )
            pushed = snapshot()
            isActive = true
            lastError = nil
            startMirroring()
            TransportLog.shared.append("lock screen: activity started")
        } catch {
            controller.holdsConnection = false
            BackgroundPresence.shared.release(.lockScreen)
            lastError = error.localizedDescription
            TransportLog.shared.append("lock screen: request failed — \(error.localizedDescription)")
        }
    }

    func stop() async {
        mirror?.cancel()
        mirror = nil
        pushed = nil

        // Detach before awaiting so an intent-driven refresh cannot push an
        // update into an activity that is on its way out.
        let ending = activity
        activity = nil
        await ending?.end(
            ActivityContent(state: snapshot(), staleDate: nil),
            dismissalPolicy: .immediate
        )

        BackgroundPresence.shared.release(.lockScreen)
        controller.holdsConnection = false
        isActive = false
        TransportLog.shared.append("lock screen: activity ended")
    }

    /// Reattaches to an activity that outlived the app process — iOS restarts the
    /// app in the background for an intent, and `Activity.request` would otherwise
    /// stack a second card on top of the first.
    func adopt() {
        guard activity == nil, let existing = Activity<RemoteActivityAttributes>.activities.first else { return }
        activity = existing
        isActive = true
        lastError = nil
        controller.holdsConnection = true
        BackgroundPresence.shared.hold(.lockScreen)
        startMirroring()
        TransportLog.shared.append("lock screen: adopted running activity")
    }

    /// Records that an intent arrived and ran. Called from the intent handlers so
    /// the Lock Screen can show that the tap got through.
    func note(_ action: String) {
        actionCount += 1
        lastAction = "\(action) \(actionCount)"
    }

    /// Pushes the current transport state into the card, skipping no-op updates so
    /// a chatty TV cannot spam ActivityKit.
    func refresh() async {
        guard let activity else { return }
        let state = snapshot()
        guard state != pushed else { return }
        pushed = state
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    private func startMirroring() {
        mirror?.cancel()
        mirror = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isActive else { return }
                await self.refresh()
            }
        }
    }

    private func snapshot() -> RemoteActivityAttributes.ContentState {
        let prefs = Preferences.shared
        let transport = controller.transport
        let app = transport.currentApp

        // Resolved here rather than in the widget: preferences live in the app,
        // and the widget should only ever render what it is handed.
        let contextKeys = prefs.contextualControls
            ? (TVAppContext.contextualKeys(for: app)?.map(\.rawValue) ?? [])
            : []
        let connection: RemoteActivityAttributes.Connection = switch transport.state {
        case .connected: .live
        case .connecting: .connecting
        case .idle, .failed: .offline
        }

        let volume = prefs.showVolumeOnLockScreen ? transport.volumeState.map {
            RemoteActivityAttributes.Volume(level: Int($0.level), max: Int($0.max), muted: $0.muted)
        } : nil

        return RemoteActivityAttributes.ContentState(
            tvName: controller.connectedTV?.serviceName ?? controller.statusTitle,
            connection: connection,
            simulated: transport.isSimulated,
            volume: volume,
            detail: controller.lastFailure,
            lastAction: lastAction,
            contextKeys: contextKeys,
            appName: TVAppContext.displayName(for: app),
            showsPower: prefs.powerKey
        )
    }
}
