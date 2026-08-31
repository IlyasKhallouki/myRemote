#if os(iOS)
import AVFAudio
#endif
import Foundation
import TVRemoteCore
import UserNotifications

/// Everything that happens because of something the TV said, rather than
/// something you pressed.
///
/// One loop rather than a watcher per feature: they all need the same connection
/// and the same 2s cadence, and a single place to see the TV's state transition
/// is far easier to reason about than three racing observers.
@MainActor
@Observable
final class Automations {
    static let shared = Automations()

    static let textRequestNotificationID = "tv-wants-text"

    private var loop: Task<Void, Never>?
    private var interruption: NSObjectProtocol?

    private var wasOn: Bool?
    private var wasAskingForText = false
    private var pausedForCall = false
    private var nextReconnect = ContinuousClock.now
    private var unreachableSince: ContinuousClock.Instant?

    /// Set by the app when a text request should raise the keyboard on screen.
    var onTextRequest: (() -> Void)?

    private var prefs: Preferences { .shared }
    private var controller: RemoteController { .shared }

    func start() {
        observeCallInterruptions()
        syncPresence()
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                await self.tick()
            }
        }
    }

    /// Called whenever a preference changes, so turning background watching on or
    /// off takes effect without restarting the app.
    func syncPresence() {
        if prefs.backgroundWatch {
            BackgroundPresence.shared.hold(.tvWatcher)
        } else {
            BackgroundPresence.shared.release(.tvWatcher)
        }
    }

    private var isWatching: Bool {
        prefs.backgroundWatch || LockScreenSession.shared.isActive
    }

    /// How long the TV has to be unreachable before we call it off rather than
    /// merely missing. A TV that has just been switched off stops answering; so
    /// does a phone that has wandered off the Wi-Fi, and only time separates them.
    private static let offAfter: Duration = .seconds(30)

    private func tick() async {
        guard isWatching else { return }

        // Self-healing: a dead socket is the difference between a green dot that
        // works and one that lies. `isLive` asks the socket, not our last belief.
        if !controller.isLive, ContinuousClock.now >= nextReconnect {
            nextReconnect = .now + .seconds(10)
            await controller.ensureLive()
        }

        let reachable = controller.isLive
        if reachable {
            unreachableSince = nil
        } else if unreachableSince == nil {
            unreachableSince = .now
        }

        // The TV only announces its power state during the handshake, so a TV
        // that switches off simply stops answering. Sustained silence is the
        // only signal there is.
        let settled = reachable || (unreachableSince.map { ContinuousClock.now - $0 >= Self.offAfter } ?? false)
        if settled {
            await reactToPower(isOn: reachable && controller.transport.isOn)
        }
        if reachable {
            await reactToTextRequest()
        }
        await LockScreenSession.shared.refresh()
    }

    // MARK: - The TV turning on and off

    private func reactToPower(isOn: Bool) async {
        defer { wasOn = isOn }
        guard let wasOn, wasOn != isOn else { return }

        if isOn, prefs.showRemoteWhenTVTurnsOn, !LockScreenSession.shared.isActive {
            TransportLog.shared.append("automation: TV came on, raising the remote")
            await LockScreenSession.shared.start()
            // iOS is entitled to refuse a Live Activity started from the
            // background. Falling back to a notification means the automation
            // still gets you to the remote in one tap instead of failing mute.
            if !LockScreenSession.shared.isActive {
                await postTVIsOnNotification()
            }
        } else if !isOn, prefs.hideRemoteWhenTVTurnsOff, LockScreenSession.shared.isActive {
            TransportLog.shared.append("automation: TV went off, dropping the remote")
            await LockScreenSession.shared.stop()
        }
    }

    // MARK: - The TV asking for text

    /// The TV pushes IME counters the moment a text field takes focus — that is
    /// how typing already knows when it is safe to send. Used as a trigger, it
    /// means the keyboard can come to you instead of the other way round.
    private func reactToTextRequest() async {
        let asking = controller.transport.canType
        defer { wasAskingForText = asking }
        guard prefs.offerKeyboardWhenTVAsks, asking, !wasAskingForText else { return }

        TransportLog.shared.append("automation: TV is asking for text")
        onTextRequest?()
        await postTextRequestNotification()
    }

    private func postTVIsOnNotification() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "The TV is on"
        content.body = "Tap to put the remote on your Lock Screen."
        content.sound = nil
        content.userInfo = ["action": "lockScreen"]

        try? await center.add(
            UNNotificationRequest(identifier: "tv-is-on", content: content, trigger: nil)
        )
    }

    private func postTextRequestNotification() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "The TV wants text"
        content.body = "Tap to type on \(controller.connectedTV?.serviceName ?? "the TV")."
        content.sound = nil
        content.userInfo = ["action": "keyboard"]

        try? await center.add(
            UNNotificationRequest(
                identifier: Self.textRequestNotificationID,
                content: content,
                trigger: nil
            )
        )
    }

    // MARK: - Phone calls

    /// We already hold an audio session for the keep-alive, so a call arriving is
    /// something we are told about for free. Off by default: pausing someone
    /// else's film because your phone rang is not universally welcome.
    private func observeCallInterruptions() {
        #if os(iOS)
        guard interruption == nil else { return }
        interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { @Sendable [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            let type = AVAudioSession.InterruptionType(rawValue: raw)
            Task { @MainActor in
                guard let self else { return }
                switch type {
                case .began: await self.pauseForCall()
                case .ended: await self.resumeAfterCall()
                default: break
                }
            }
        }
        #endif
    }

    private func pauseForCall() async {
        guard prefs.pauseTVOnPhoneCall, !pausedForCall, controller.isLive else { return }
        pausedForCall = true
        TransportLog.shared.append("automation: call started, pausing the TV")
        await controller.perform(.playPause)
    }

    private func resumeAfterCall() async {
        guard pausedForCall else { return }
        pausedForCall = false
        guard prefs.resumeTVAfterPhoneCall else { return }
        TransportLog.shared.append("automation: call ended, resuming the TV")
        await controller.perform(.playPause)
    }
}
