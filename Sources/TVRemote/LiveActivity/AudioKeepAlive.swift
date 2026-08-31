#if os(iOS)
import AVFAudio
import Foundation
import TVRemoteCore

/// Holds the app's process alive while the Lock Screen remote is up.
///
/// A Live Activity buys you a UI on the Lock Screen but *not* background
/// execution: without this, iOS suspends the app between presses, the socket to
/// the TV dies unnoticed, and every key is dropped. Playing under the `audio`
/// background mode keeps the process — and therefore the session — alive.
/// `.mixWithOthers` keeps it from interrupting music or claiming Now Playing.
///
/// This is exactly the trick App Review rejects apps for. It is fine here because
/// the app is sideloaded, but it is also why it only runs while a session is up.
@MainActor
final class AudioKeepAlive {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var observers: [NSObjectProtocol] = []

    private(set) var isRunning = false
    private(set) var lastFailure: String?

    func start() {
        guard !isRunning else { return }
        observe()
        do {
            try startEngine()
            isRunning = true
            lastFailure = nil
            TransportLog.shared.append("keepalive: holding the process open")
        } catch {
            lastFailure = error.localizedDescription
            TransportLog.shared.append("keepalive failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []

        guard isRunning else { return }
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        isRunning = false

        // Deliberately NOT .notifyOthersOnDeactivation: that flag exists to tell
        // other audio apps they may resume, and Spotify obeys it — it would
        // restart music the user had paused. We mix with others and never
        // interrupt anyone, so there is nothing to hand back.
        try? AVAudioSession.sharedInstance().setActive(false)
        TransportLog.shared.append("keepalive: released")
    }

    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100) else {
            throw KeepAliveError.noBuffer
        }
        buffer.frameLength = buffer.frameCapacity
        fillInaudible(buffer)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()

        self.engine = engine
        self.player = player
    }

    /// A tone at roughly -80 dBFS: inaudible, but not digital silence.
    ///
    /// iOS suspends apps whose audio output is nothing but zeroes, which is what
    /// was cutting the session short. A signal this quiet is below the noise
    /// floor of any speaker yet still counts as playing audio.
    private func fillInaudible(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData else { return }
        let amplitude: Float = 0.0001
        let step = 2 * Float.pi * 440 / 44_100
        for frame in 0..<Int(buffer.frameLength) {
            channel[0][frame] = amplitude * sin(step * Float(frame))
        }
    }

    /// Phone calls, Siri and media-server resets all stop the engine without
    /// telling us. Each one used to end the session silently; now we rebuild.
    private func observe() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { @Sendable [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            guard AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            Task { @MainActor in self?.restart(because: "interruption ended") }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { @Sendable [weak self] _ in
            Task { @MainActor in self?.restart(because: "media services reset") }
        })
    }

    private func restart(because reason: String) {
        guard isRunning else { return }
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        do {
            try startEngine()
            TransportLog.shared.append("keepalive: restarted after \(reason)")
        } catch {
            isRunning = false
            lastFailure = error.localizedDescription
            TransportLog.shared.append("keepalive: could not restart after \(reason)")
        }
    }

    private enum KeepAliveError: LocalizedError {
        case noBuffer
        var errorDescription: String? { "Could not build the keep-alive audio buffer." }
    }
}
#else
@MainActor
final class AudioKeepAlive {
    private(set) var isRunning = false
    private(set) var lastFailure: String?
    func start() {}
    func stop() {}
}
#endif
