import AppIntents

/// Declares this module as a source of App Intents.
///
/// The intents live here, but the types are referenced from two other modules —
/// the app and the widget extension. Apple's guidance for that split is that the
/// defining module and every module referring to it each vend an
/// `AppIntentsPackage`, so the runtime can find them across the boundary.
public struct TVRemoteCorePackage: AppIntentsPackage {}
