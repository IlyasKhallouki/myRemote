import Foundation

struct Macro: Identifiable, Sendable {
    let id: String
    let label: String
    let symbol: String
    let accented: Bool

    static let all: [Macro] = [
        Macro(id: "stream-pc", label: "Stream PC", symbol: "desktopcomputer", accented: true),
        Macro(id: "xbox", label: "Xbox", symbol: "gamecontroller", accented: false),
        Macro(id: "movie-night", label: "Movie night", symbol: "film", accented: false),
        Macro(id: "reset", label: "Reset", symbol: "arrow.clockwise", accented: false),
    ]

    func endpoint(base: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let root = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: "\(root)/macro/\(id)")
    }
}
