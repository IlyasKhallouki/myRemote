import Foundation

enum MacroAction: Sendable {
    case keys([RemoteKey])
    case server
}

struct Macro: Identifiable, Sendable {
    let id: String
    let label: String
    let symbol: String
    let accented: Bool
    let action: MacroAction

    static let all: [Macro] = [
        Macro(id: "stream-pc", label: "Stream PC", symbol: "desktopcomputer", accented: true, action: .server),
        Macro(id: "xbox", label: "Xbox", symbol: "gamecontroller", accented: false, action: .keys([.tvInputHDMI1])),
        Macro(id: "movie-night", label: "Movie night", symbol: "film", accented: false, action: .server),
        Macro(id: "reset", label: "Reset", symbol: "arrow.clockwise", accented: false, action: .keys([.back, .back, .home])),
    ]

    func endpoint(base: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let root = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: "\(root)/macro/\(id)")
    }
}
