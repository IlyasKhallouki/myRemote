/// Where a Lock Screen button press lands.
///
/// The intents live in this module because the widget binary has to contain them
/// in order to build a `Button(intent:)`, but the transport lives in the app.
/// `LiveActivityIntent` guarantees `perform()` runs in the *app's* process, so the
/// app installs its handlers at launch and the intent just forwards to them.
@MainActor
public enum RemoteIntentBridge {
    public static var sendKey: (@MainActor (RemoteKey) async -> Void)?
    public static var runMacro: (@MainActor (String) async -> Void)?
    public static var endSession: (@MainActor () async -> Void)?

    /// Driven from Shortcuts, Siri, the Action Button or the share sheet, and
    /// gated separately from the Lock Screen's own buttons.
    public static var externalCommand: (@MainActor (String) async -> Void)?
    public static var externalLink: (@MainActor (String) async -> Void)?
}
