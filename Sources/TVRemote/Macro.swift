import Foundation

/// Verified against MiTV-MOOR2 over adb. A bare package name does not launch anything:
/// the TV resolves an app link as an ACTION_VIEW URI, so each entry must be one.
/// `www.youtube.com` is claimed by two installed YouTube apps and raises a chooser,
/// hence the vnd.youtube scheme. HW4 is hdmi_port 1 on this panel.
enum AppLinks {
    static let youTube = "vnd.youtube://"
    static let spotify = "spotify://"
    static let hdmi1 = "content://android.media.tv/passthrough/com.mediatek.tvinput%2F.hdmi.HDMIInputService%2FHW4"
}

enum MacroAction: Sendable {
    case keys([RemoteKey])
    case launch(String)
    case server
}

struct Macro: Identifiable, Sendable {
    let id: String
    let label: String
    let symbol: String
    let accented: Bool
    let action: MacroAction

    static let all: [Macro] = [
        Macro(id: "xbox", label: "Xbox", symbol: "gamecontroller", accented: true, action: .launch(AppLinks.hdmi1)),
        Macro(id: "youtube", label: "YouTube", symbol: "play.rectangle", accented: false, action: .launch(AppLinks.youTube)),
        Macro(id: "spotify", label: "Spotify", symbol: "music.note", accented: false, action: .launch(AppLinks.spotify)),
        Macro(id: "netflix", label: "Netflix", symbol: "film", accented: false, action: .launch("nflx://")),
    ]

    func endpoint(base: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let root = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: "\(root)/macro/\(id)")
    }
}
