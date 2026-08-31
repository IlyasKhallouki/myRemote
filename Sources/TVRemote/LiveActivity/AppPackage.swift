import AppIntents
import TVRemoteCore

/// See `TVRemoteCorePackage`: the app refers to intents defined in another module,
/// so it has to point at that module's package.
struct TVRemoteAppPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TVRemoteCorePackage.self]
    }
}
