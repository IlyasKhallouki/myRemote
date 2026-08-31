import SwiftUI
import TVRemoteCore

struct DPadView: View {
    let send: (RemoteKey) -> Void

    @State private var firedThisGesture = false

    private let chevronInset: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Color.surfaceRaised)

                chevron("chevron.up", key: .up, offset: CGSize(width: 0, height: -(diameter / 2 - chevronInset - 8)))
                chevron("chevron.down", key: .down, offset: CGSize(width: 0, height: diameter / 2 - chevronInset - 8))
                chevron("chevron.left", key: .left, offset: CGSize(width: -(diameter / 2 - chevronInset - 8), height: 0))
                chevron("chevron.right", key: .right, offset: CGSize(width: diameter / 2 - chevronInset - 8, height: 0))

                Circle()
                    .fill(Color.surfaceInset)
                    .overlay(Circle().stroke(Color.hairline, lineWidth: 1))
                    .frame(width: 112, height: 112)
                    .overlay(
                        Text("OK")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    )
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .gesture(dragGesture)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !firedThisGesture else { return }
                guard let direction = DPadResolution.direction(for: value.translation) else { return }
                firedThisGesture = true
                send(direction)
            }
            .onEnded { _ in
                if !firedThisGesture { send(.ok) }
                firedThisGesture = false
            }
    }

    private func chevron(_ name: String, key: RemoteKey, offset: CGSize) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Color.textSecondary)
            .frame(width: 56, height: 56)
            .contentShape(Rectangle())
            .offset(x: offset.width, y: offset.height)
            .onTapGesture { send(key) }
    }
}
