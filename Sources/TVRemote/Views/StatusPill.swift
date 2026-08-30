import SwiftUI

struct StatusPill: View {
    let title: String
    let state: TransportState

    private var dotColor: Color {
        switch state {
        case .connected: .statusOK
        case .failed: .red
        case .idle, .connecting: .textMuted
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.surfaceRaised))
    }
}
