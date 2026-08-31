import AppIntents
import Foundation

/// Intents meant to be driven from *outside* the app — Shortcuts, Siri, the
/// Action Button, the share sheet.
///
/// Kept separate from the Lock Screen intents on purpose. These are the ones
/// that are discoverable, and the ones the "Allow outside control" preference
/// gates; the Lock Screen's own buttons must never be switched off by a setting
/// that is about Shortcuts.
public struct TVRemoteControlIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Control the TV"
    public static var isDiscoverable: Bool { true }

    /// A `RemoteKey` raw value (`ok`, `volumeUp`, `power`, …) or a macro id
    /// (`xbox`, `youtube`, `spotify`). One free-text field rather than an
    /// `AppEnum` because enums need their own metadata, which is the part of the
    /// App Intents format we are generating by hand.
    @Parameter(title: "Command")
    public var command: String

    public init() {}

    public init(command: String) {
        self.command = command
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        await RemoteIntentBridge.externalCommand?(command)
        return .result()
    }
}

/// Sends a link to the TV. Pair it with a Shortcut that accepts URLs and it
/// appears in the share sheet, so a video in Safari goes to the TV directly.
public struct SendLinkToTVIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Send Link to TV"
    public static var isDiscoverable: Bool { true }

    @Parameter(title: "Link")
    public var link: String

    public init() {}

    public init(link: String) {
        self.link = link
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        await RemoteIntentBridge.externalLink?(link)
        return .result()
    }
}

/// Turns a phone-side URL into something the TV will actually open.
///
/// The TV resolves an app link as an ACTION_VIEW URI, so a plain https link
/// usually raises an app chooser or lands in the browser. Rewriting the handful
/// of hosts worth caring about is what makes share-to-TV feel deliberate.
public enum LinkRewriter {
    public static func tvLink(for raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return trimmed
        }

        if host.contains("youtu.be") {
            let id = url.lastPathComponent
            return id.isEmpty ? AppLinks.youTube : "\(AppLinks.youTube)\(id)"
        }
        if host.contains("youtube.") {
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "v" }?.value
            return id.map { "\(AppLinks.youTube)\($0)" } ?? AppLinks.youTube
        }
        if host.contains("spotify.") {
            // open.spotify.com/track/ID -> spotify:track:ID
            let parts = url.pathComponents.filter { $0 != "/" }
            return parts.count >= 2 ? "spotify:\(parts[0]):\(parts[1])" : AppLinks.spotify
        }
        return trimmed
    }
}
