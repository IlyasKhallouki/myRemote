import Foundation
import TVRemoteCore

enum DPadResolution {
    static let threshold: CGFloat = 24

    static func direction(for translation: CGSize, threshold: CGFloat = threshold) -> RemoteKey? {
        let dx = translation.width
        let dy = translation.height
        guard max(abs(dx), abs(dy)) >= threshold else { return nil }
        if abs(dx) >= abs(dy) {
            return dx > 0 ? .right : .left
        }
        return dy > 0 ? .down : .up
    }
}
