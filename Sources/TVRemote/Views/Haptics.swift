#if canImport(UIKit)
import UIKit

@MainActor
final class Haptics {
    private let generator = UIImpactFeedbackGenerator(style: .light)

    func prepare() { generator.prepare() }

    func fire() {
        generator.impactOccurred()
        generator.prepare()
    }
}
#else
@MainActor
final class Haptics {
    func prepare() {}
    func fire() {}
}
#endif
