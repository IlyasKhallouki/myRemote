#if canImport(UIKit)
import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

/// Repurposes the iPhone's volume rocker to drive the TV.
///
/// iOS quantises system volume into 16 steps of 0.0625. We observe changes, convert the
/// delta into a signed press count, then snap back to the midpoint so the rocker never
/// runs out of travel at 0.0 or 1.0.
@MainActor
@Observable
final class HardwareVolume {
    static let step: Float = 0.0625
    private static let centre: Float = 0.5

    private(set) var isActive = false

    let anchor = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))

    private var observation: NSKeyValueObservation?
    private var isRecentring = false
    private var onPress: ((RemoteKey, Int) -> Void)?

    func start(onPress: @escaping (RemoteKey, Int) -> Void) {
        guard !isActive else { return }
        self.onPress = onPress

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            TransportLog.shared.append("volume buttons unavailable: \(error.localizedDescription)")
            return
        }

        anchor.alpha = 0.01
        anchor.isUserInteractionEnabled = false
        isActive = true
        TransportLog.shared.append("volume buttons armed, level \(session.outputVolume)")
        recentre()

        observation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            guard let old = change.oldValue, let new = change.newValue else { return }
            Task { @MainActor in self?.handle(old: old, new: new) }
        }
    }

    func stop() {
        observation?.invalidate()
        observation = nil
        isActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func handle(old: Float, new: Float) {
        TransportLog.shared.append("rocker \(old) -> \(new)\(isRecentring ? " (ignored, recentring)" : "")")
        guard !isRecentring else { return }
        let steps = Int(((new - old) / Self.step).rounded())
        guard steps != 0 else { return }
        onPress?(steps > 0 ? .volumeUp : .volumeDown, abs(steps))
        recentre()
    }

    private func recentre() {
        guard let slider = anchor.subviews.compactMap({ $0 as? UISlider }).first else {
            TransportLog.shared.append("recentre FAILED: no slider in MPVolumeView")
            return
        }
        isRecentring = true
        slider.value = Self.centre
        slider.sendActions(for: .touchUpInside)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            self.isRecentring = false
        }
    }
}

/// Hosts the MPVolumeView in the live hierarchy — required for the re-centre write to
/// take effect. A view parked off-screen reads zero and does nothing.
struct VolumeAnchorView: UIViewRepresentable {
    let anchor: MPVolumeView

    func makeUIView(context: Context) -> MPVolumeView { anchor }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
#endif
