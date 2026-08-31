import Foundation
import TVRemoteCore
import UserNotifications

/// Sends a tapped notification somewhere useful.
///
/// Only one notification exists today — the TV asking for text — and tapping it
/// should land you on the keyboard, not on the remote with the keyboard still
/// two taps away.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    // Stateless, so the only thing @unchecked is waving through is the
    // UNUserNotificationCenterDelegate conformance itself.
    static let shared = NotificationRouter()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.notification.request.content.userInfo["action"] as? String {
        case "keyboard":
            await MainActor.run { Automations.shared.onTextRequest?() }
        case "lockScreen":
            // Opening the app puts us in the foreground, where starting a Live
            // Activity is always allowed.
            await LockScreenSession.shared.start()
        default:
            break
        }
    }

    /// Worth showing even in the foreground: the TV focusing a text field is
    /// something you want to know about while looking at the remote too.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
