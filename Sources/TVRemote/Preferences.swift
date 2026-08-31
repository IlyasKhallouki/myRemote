import Foundation
import TVRemoteCore

/// Every optional behaviour in the app, in one place, backed by `UserDefaults`.
///
/// Deliberately all opt-in except the two that only affect an already-running
/// Lock Screen session: anything that keeps the process awake costs battery, so
/// it should never switch itself on.
@MainActor
@Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    // MARK: - Background presence

    /// Holds the app awake even with no Lock Screen session, so it can watch the
    /// TV. Every automation below needs it, which is why they read as disabled
    /// in Settings until this is on.
    var backgroundWatch: Bool { didSet { defaults.set(backgroundWatch, forKey: "pref.backgroundWatch") } }

    /// A TV address to use instead of waiting for Bonjour. Discovery needs
    /// multicast, which plenty of networks quietly drop; the session port is
    /// reachable either way, so a fixed address makes the app work regardless.
    var manualHost: String { didSet { defaults.set(manualHost, forKey: "pref.manualHost") } }

    // MARK: - Automations

    var showRemoteWhenTVTurnsOn: Bool { didSet { defaults.set(showRemoteWhenTVTurnsOn, forKey: "pref.showRemoteWhenTVTurnsOn") } }
    var hideRemoteWhenTVTurnsOff: Bool { didSet { defaults.set(hideRemoteWhenTVTurnsOff, forKey: "pref.hideRemoteWhenTVTurnsOff") } }
    var pauseTVOnPhoneCall: Bool { didSet { defaults.set(pauseTVOnPhoneCall, forKey: "pref.pauseTVOnPhoneCall") } }
    var resumeTVAfterPhoneCall: Bool { didSet { defaults.set(resumeTVAfterPhoneCall, forKey: "pref.resumeTVAfterPhoneCall") } }
    var offerKeyboardWhenTVAsks: Bool { didSet { defaults.set(offerKeyboardWhenTVAsks, forKey: "pref.offerKeyboardWhenTVAsks") } }

    // MARK: - Lock Screen

    var contextualControls: Bool { didSet { defaults.set(contextualControls, forKey: "pref.contextualControls") } }
    var showVolumeOnLockScreen: Bool { didSet { defaults.set(showVolumeOnLockScreen, forKey: "pref.showVolumeOnLockScreen") } }

    // MARK: - Shortcuts and Siri

    /// Master switch for anything driven from outside the app — Shortcuts, Siri,
    /// the Action Button, the share sheet. The intents still exist when this is
    /// off; they just decline to do anything.
    var allowShortcutsControl: Bool { didSet { defaults.set(allowShortcutsControl, forKey: "pref.allowShortcutsControl") } }

    // MARK: - Experimental protocol

    /// Sends an absolute volume level instead of stepping. The message shape is
    /// inferred from what the TV reports, not verified against it, so it stays
    /// off until you have confirmed it with Tools/probe-volume-and-power.py.
    var absoluteVolume: Bool { didSet { defaults.set(absoluteVolume, forKey: "pref.absoluteVolume") } }

    /// Shows a power key. The TV advertises the power feature during the
    /// handshake, but which keycode it honours varies by panel.
    var powerKey: Bool { didSet { defaults.set(powerKey, forKey: "pref.powerKey") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func flag(_ key: String, default fallback: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallback
        }
        backgroundWatch = flag("pref.backgroundWatch", default: false)
        manualHost = defaults.string(forKey: "pref.manualHost") ?? ""
        showRemoteWhenTVTurnsOn = flag("pref.showRemoteWhenTVTurnsOn", default: false)
        hideRemoteWhenTVTurnsOff = flag("pref.hideRemoteWhenTVTurnsOff", default: false)
        pauseTVOnPhoneCall = flag("pref.pauseTVOnPhoneCall", default: false)
        resumeTVAfterPhoneCall = flag("pref.resumeTVAfterPhoneCall", default: false)
        offerKeyboardWhenTVAsks = flag("pref.offerKeyboardWhenTVAsks", default: false)
        contextualControls = flag("pref.contextualControls", default: true)
        showVolumeOnLockScreen = flag("pref.showVolumeOnLockScreen", default: true)
        allowShortcutsControl = flag("pref.allowShortcutsControl", default: true)
        absoluteVolume = flag("pref.absoluteVolume", default: false)
        powerKey = flag("pref.powerKey", default: false)
    }
}
