import AppIntents

/// Sends one key press from the Lock Screen.
///
/// `LiveActivityIntent` (rather than plain `AppIntent`) is what makes iOS run this
/// in the app process, where the TLS session to the TV lives; a plain intent would
/// run in the widget extension and have nothing to talk to.
public struct SendRemoteKeyIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Send Remote Key"

    /// Keeps it out of the Shortcuts action list; the app already ships a
    /// `lumindtv://` URL scheme for that.
    ///
    /// The default authentication policy is deliberately left alone: it is what
    /// lets a Lock Screen button run without unlocking, and it is what
    /// `Metadata.appintents` describes. Overriding it here would desync the two.
    public static var isDiscoverable: Bool { false }


    @Parameter(title: "Key")
    public var key: String

    public init() {}

    public init(_ key: RemoteKey) {
        self.key = key.rawValue
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard let key = RemoteKey(rawValue: key) else { return .result() }
        await RemoteIntentBridge.sendKey?(key)
        return .result()
    }
}

/// Runs one of the launch macros (Xbox, YouTube, Spotify) from the Lock Screen.
public struct RunRemoteMacroIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Run Remote Macro"
    public static var isDiscoverable: Bool { false }

    @Parameter(title: "Macro")
    public var macroID: String

    public init() {}

    public init(_ macro: Macro) {
        self.macroID = macro.id
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        await RemoteIntentBridge.runMacro?(macroID)
        return .result()
    }
}

/// Dismisses the Live Activity and drops the connection.
public struct EndRemoteSessionIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "End Remote Session"
    public static var isDiscoverable: Bool { false }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        await RemoteIntentBridge.endSession?()
        return .result()
    }
}
