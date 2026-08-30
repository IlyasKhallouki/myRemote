import Foundation

enum DeepLinkAction: Equatable {
    case key(RemoteKey)
    case macro(String)
}

enum DeepLink {
    static let scheme = "lumindtv"

    static func parse(_ url: URL) -> DeepLinkAction? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        let segments = ([url.host] + url.pathComponents)
            .compactMap { $0 }
            .filter { $0 != "/" && !$0.isEmpty }
        guard segments.count >= 2 else { return nil }

        let argument = normalize(segments[1])
        switch normalize(segments[0]) {
        case "key":
            return RemoteKey.allCases
                .first { normalize($0.rawValue) == argument }
                .map(DeepLinkAction.key)
        case "macro":
            return Macro.all
                .first { normalize($0.id) == argument }
                .map { .macro($0.id) }
        default:
            return nil
        }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
