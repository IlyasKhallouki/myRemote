import Foundation

/// Verified against MiTV-MOOR2 over adb. A bare package name does not launch anything:
/// the TV resolves an app link as an ACTION_VIEW URI, so each entry must be one.
/// `www.youtube.com` is claimed by two installed YouTube apps and raises a chooser,
/// hence the vnd.youtube scheme. HW4 is hdmi_port 1 on this panel.
public enum AppLinks {
    public static let youTube = "vnd.youtube://"
    public static let spotify = "spotify://"
    public static let hdmi1 = "content://android.media.tv/passthrough/com.mediatek.tvinput%2F.hdmi.HDMIInputService%2FHW4"
}

public enum MacroAction: Sendable {
    case keys([RemoteKey])
    case launch(String)
    case keyboard
    case server
}

public struct Macro: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let symbol: String
    public let accented: Bool
    public let action: MacroAction

    public static let all: [Macro] = [
        Macro(id: "xbox", label: "Xbox", symbol: "gamecontroller", accented: true, action: .launch(AppLinks.hdmi1)),
        Macro(id: "youtube", label: "YouTube", symbol: "play.rectangle", accented: false, action: .launch(AppLinks.youTube)),
        Macro(id: "spotify", label: "Spotify", symbol: "music.note", accented: false, action: .launch(AppLinks.spotify)),
        Macro(id: "keyboard", label: "Keyboard", symbol: "keyboard", accented: false, action: .keyboard),
    ]

    /// The subset the Live Activity offers. Only `.launch` macros qualify: the
    /// keyboard needs a sheet and the server macros need a reachable host.
    public static var lockScreen: [Macro] {
        all.filter { if case .launch = $0.action { true } else { false } }
    }

    public func endpoint(base: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let root = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: "\(root)/macro/\(id)")
    }
}
