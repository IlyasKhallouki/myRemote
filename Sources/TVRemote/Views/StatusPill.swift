import SwiftUI
import TVRemoteCore

struct StatusPill: View {
    let title: String
    let state: TransportState
    let simulated: Bool

    private var dotColor: Color {
        switch state {
        case .connected: simulated ? .statusSimulated : .statusOK
        case .failed: .red
        case .idle, .connecting: .textMuted
        }
    }

    private var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
            if simulated && isConnected {
                Text("mock")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.surfaceRaised))
    }
}
