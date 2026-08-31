import SwiftUI
import TVRemoteCore

@main
struct TVRemoteApp: App {
    init() {
        Self.installIntentHandlers()
    }

    var body: some Scene {
        WindowGroup {
            RemoteView()
        }
    }

    /// Wired up in `init` rather than in a view because iOS relaunches the app in
    /// the background purely to run a Lock Screen intent — no scene is ever created
    /// on that path, so anything hung off `RemoteView` would never run.
    @MainActor
    private static func installIntentHandlers() {
        RemoteIntentBridge.sendKey = { key in
            TransportLog.shared.append("intent: key \(key.rawValue)")
            let sent = await RemoteController.shared.perform(key)
            LockScreenSession.shared.note("\(key.rawValue) \(sent ? "ok" : "fail")")
            await LockScreenSession.shared.refresh()
        }

        RemoteIntentBridge.runMacro = { id in
            TransportLog.shared.append("intent: macro \(id)")
            guard let macro = Macro.all.first(where: { $0.id == id }),
                  case let .launch(link) = macro.action else { return }
            let sent = await RemoteController.shared.launch(link)
            LockScreenSession.shared.note("\(macro.id) \(sent ? "ok" : "fail")")
            await LockScreenSession.shared.refresh()
        }

        RemoteIntentBridge.externalCommand = { command in
            guard Preferences.shared.allowShortcutsControl else {
                TransportLog.shared.append("external: \(command) refused (outside control is off)")
                return
            }
            TransportLog.shared.append("external: command \(command)")
            if let key = RemoteKey(rawValue: command) {
                await RemoteController.shared.perform(key)
            } else if let macro = Macro.all.first(where: { $0.id == command }),
                      case let .launch(link) = macro.action {
                await RemoteController.shared.launch(link)
            } else {
                TransportLog.shared.append("external: no key or macro named \(command)")
            }
            await LockScreenSession.shared.refresh()
        }

        RemoteIntentBridge.externalLink = { raw in
            guard Preferences.shared.allowShortcutsControl else {
                TransportLog.shared.append("external: link refused (outside control is off)")
                return
            }
            guard let link = LinkRewriter.tvLink(for: raw) else { return }
            TransportLog.shared.append("external: link \(link)")
            await RemoteController.shared.launch(link)
            await LockScreenSession.shared.refresh()
        }

        RemoteIntentBridge.endSession = {
            TransportLog.shared.append("intent: end session")
            await LockScreenSession.shared.stop()
        }

        Task { @MainActor in
            NetworkReachability.shared.start()
            NotificationRouter.shared.install()
            LockScreenSession.shared.adopt()
            Automations.shared.start()
        }
    }
}
