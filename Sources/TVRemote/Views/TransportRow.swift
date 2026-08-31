import SwiftUI
import TVRemoteCore

struct TransportRow: View {
    let send: (RemoteKey) -> Void
    let volume: VolumeState?

    @State private var firedThisGesture = false

    private let height: CGFloat = 56

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                button("chevron.backward", key: .back)
                button("house", key: .home)
                button("playpause", key: .playPause)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Capsule().fill(Color.surfaceRaised))

            Image(systemName: volume?.muted == true ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 19))
                .foregroundStyle(volume?.muted == true ? Color.accentText : Color.textSecondary)
                .frame(width: height, height: height)
                .background(Capsule().fill(Color.surfaceRaised))
                .contentShape(Capsule())
                .gesture(volumeGesture)
        }
    }

    private var volumeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !firedThisGesture else { return }
                let vertical = CGSize(width: 0, height: value.translation.height)
                guard let direction = DPadResolution.direction(for: vertical) else { return }
                firedThisGesture = true
                send(direction == .up ? .volumeUp : .volumeDown)
            }
            .onEnded { _ in
                if !firedThisGesture { send(.volumeMute) }
                firedThisGesture = false
            }
    }

    private func button(_ symbol: String, key: RemoteKey) -> some View {
        Button {
            send(key)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
