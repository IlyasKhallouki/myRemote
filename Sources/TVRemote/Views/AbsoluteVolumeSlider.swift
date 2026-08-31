import SwiftUI
import TVRemoteCore

/// Drag straight to a volume rather than tapping up eleven times.
///
/// Only possible because the TV reports its own level and maximum, which is a
/// channel most remotes never read.
struct AbsoluteVolumeSlider: View {
    let volume: VolumeState
    let set: (UInt64) -> Void

    @State private var dragging: Double?

    private var displayed: Double {
        dragging ?? Double(volume.level)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Volume")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
                Spacer()
                Text("\(Int(displayed)) / \(volume.max)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
            }

            GeometryReader { proxy in
                let fraction = volume.max > 0 ? displayed / Double(volume.max) : 0
                Capsule()
                    .fill(Color.surfaceInset)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentText)
                            .frame(width: max(0, min(1, fraction)) * proxy.size.width)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let ratio = max(0, min(1, value.location.x / proxy.size.width))
                                dragging = (ratio * Double(volume.max)).rounded()
                            }
                            .onEnded { _ in
                                if let dragging { set(UInt64(dragging)) }
                                dragging = nil
                            }
                    )
            }
            .frame(height: 10)
        }
    }
}
