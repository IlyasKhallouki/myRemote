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
}

enum MacroState: Equatable {
    case idle
    case inFlight
    case succeeded
    case failed(String)
}

@MainActor
@Observable
final class MacroService {
    static let baseURLDefaultsKey = "macroBaseURL"
    static let resultLinger: Duration = .seconds(4)

    private(set) var states: [String: MacroState] = [:]

    private let defaults: UserDefaults
    private let session: URLSession
    private var clearTasks: [String: Task<Void, Never>] = [:]

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
    }

    var baseURL: String {
        get { defaults.string(forKey: Self.baseURLDefaultsKey) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Self.baseURLDefaultsKey) }
    }

    func state(for macro: Macro) -> MacroState {
        states[macro.id] ?? .idle
    }

    func run(_ macro: Macro) async {
        guard state(for: macro) != .inFlight else { return }
        clearTasks[macro.id]?.cancel()

        guard let url = endpoint(for: macro) else {
            settle(macro, .failed("No server configured"))
            return
        }

        states[macro.id] = .inFlight
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        do {
            let (_, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            settle(macro, (200..<300).contains(code) ? .succeeded : .failed("HTTP \(code)"))
        } catch {
            settle(macro, .failed("Unreachable"))
        }
    }

    func endpoint(for macro: Macro) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let base = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: "\(base)/macro/\(macro.id)")
    }

    private func settle(_ macro: Macro, _ state: MacroState) {
        states[macro.id] = state
        clearTasks[macro.id] = Task { [weak self] in
            try? await Task.sleep(for: Self.resultLinger)
            guard !Task.isCancelled else { return }
            self?.states[macro.id] = .idle
        }
    }
}
