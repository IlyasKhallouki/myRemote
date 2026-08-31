import AppIntents
import TVRemoteCore

/// See `TVRemoteCorePackage`: the widget builds `Button(intent:)` from intents
/// defined in another module, so it has to point at that module's package.
struct TVRemoteWidgetPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TVRemoteCorePackage.self]
    }
}
