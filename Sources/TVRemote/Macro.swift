import Foundation

/// Package identifiers on the TV. Confirm these against `adb shell pm list packages`
/// rather than trusting the defaults — they vary by firmware.
enum AppIDs {
    static let youTube = "com.google.android.youtube.tv"
    static let spotify = "com.spotify.tv.android"
    static let miracast = "com.xiaomi.mitv.smartshare"
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
        Macro(id: "xbox", label: "Xbox", symbol: "gamecontroller", accented: true, action: .keys([.tvInputHDMI1])),
        Macro(id: "youtube", label: "YouTube", symbol: "play.rectangle", accented: false, action: .launch(AppIDs.youTube)),
        Macro(id: "spotify", label: "Spotify", symbol: "music.note", accented: false, action: .launch(AppIDs.spotify)),
        Macro(id: "miracast", label: "Miracast", symbol: "airplayvideo", accented: false, action: .launch(AppIDs.miracast)),
    ]

    func endpoint(base: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let root = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: "\(root)/macro/\(id)")
    }
}
