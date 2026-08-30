import SwiftUI

struct DPadView: View {
    let send: (RemoteKey) -> Void

    @State private var firedThisGesture = false

    private let chevronInset: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Color.surfaceRaised)

                chevron("chevron.up", offset: CGSize(width: 0, height: -(diameter / 2 - chevronInset - 8)))
                chevron("chevron.down", offset: CGSize(width: 0, height: diameter / 2 - chevronInset - 8))
                chevron("chevron.left", offset: CGSize(width: -(diameter / 2 - chevronInset - 8), height: 0))
                chevron("chevron.right", offset: CGSize(width: diameter / 2 - chevronInset - 8, height: 0))

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

    private func chevron(_ name: String, offset: CGSize) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Color.textSecondary)
            .offset(x: offset.width, y: offset.height)
    }
}
