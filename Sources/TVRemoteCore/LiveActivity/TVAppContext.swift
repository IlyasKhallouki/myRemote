/// What the TV is currently running, and what that should change about the remote.
///
/// The TV reports the foreground package alongside its IME messages, so this is
/// information no ordinary remote has. The use we make of it: when you are
/// already inside a media app, a button that launches that app is dead weight,
/// while scrubbing controls are exactly what you reach for.
public enum TVAppContext {
    /// Packages known to be media players, matched loosely because vendors ship
    /// several variants of the same app on one panel.
    private static let mediaFragments = [
        "youtube", "spotify", "netflix", "primevideo", "amazon.avod",
        "disney", "plex", "jellyfin", "kodi", "vlc", "twitch",
    ]

    public static func isMediaApp(_ package: String) -> Bool {
        guard !package.isEmpty else { return false }
        let lowered = package.lowercased()
        return mediaFragments.contains { lowered.contains($0) }
    }

    /// The keys to offer in place of the launch macros, or nil to keep the macros.
    public static func contextualKeys(for package: String) -> [RemoteKey]? {
        guard isMediaApp(package) else { return nil }
        return [.rewind, .fastForward, .next]
    }

    /// A short human name for the foreground app, for the Lock Screen header.
    public static func displayName(for package: String) -> String? {
        guard !package.isEmpty else { return nil }
        let lowered = package.lowercased()
        for fragment in mediaFragments where lowered.contains(fragment) {
            return fragment.prefix(1).uppercased() + fragment.dropFirst()
        }
        return nil
    }
}
