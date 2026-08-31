import AppIntents
import SwiftUI
import TVRemoteCore
import WidgetKit

/// One button on the Lock Screen.
///
/// Every control here is a `Button(intent:)`. The intent conforms to
/// `LiveActivityIntent`, so iOS runs it in the app's process — where the TLS
/// session to the TV lives — instead of in this widget process.
struct RemoteButton<Intent: LiveActivityIntent, Label: View>: View {
    /// Generic rather than `any LiveActivityIntent`: `Button(intent:)` takes a
    /// concrete intent, so an existential here fails to type-check.
    let intent: Intent
    var tint: Color = .textPrimary
    var fill: Color = .surfaceRaised
    var size: CGFloat = 32
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(intent: intent) {
            label()
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: size)
                .background(RoundedRectangle(cornerRadius: 10).fill(fill))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct KeyButton: View {
    let key: RemoteKey
    var size: CGFloat = 32
    var emphasised = false

    var body: some View {
        RemoteButton(
            intent: SendRemoteKeyIntent(key),
            tint: emphasised ? .accentText : .textPrimary,
            fill: emphasised ? .accentWash : .surfaceRaised,
            size: size
        ) {
            Image(systemName: key.symbol)
        }
        .accessibilityLabel(key.label)
    }
}

struct MacroButton: View {
    let macro: Macro
    var size: CGFloat = 32

    var body: some View {
        RemoteButton(
            intent: RunRemoteMacroIntent(macro),
            tint: macro.accented ? .accentText : .textSecondary,
            fill: macro.accented ? .accentWash : .surfaceRaised,
            size: size
        ) {
            Image(systemName: macro.symbol)
        }
        .accessibilityLabel(macro.label)
    }
}

/// Empty grid cell — keeps the d-pad cross aligned without a spacer hack.
struct ControlGap: View {
    var size: CGFloat = 32
    var body: some View {
        Color.clear.frame(height: size)
    }
}

struct ConnectionDot: View {
    let state: RemoteActivityAttributes.ContentState

    private var color: Color {
        switch state.connection {
        case .live: state.simulated ? .statusSimulated : .statusOK
        case .connecting: .textMuted
        case .offline: .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

struct ActivityHeader: View {
    let state: RemoteActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            ConnectionDot(state: state)
            Text(state.detail ?? state.appName ?? state.tvName)
                .font(.system(size: 12))
                .foregroundStyle(state.detail == nil ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Changes on every tap that reaches the app. If tapping a key never
            // changes this, the intent is not being dispatched at all.
            if let action = state.lastAction {
                Text(action)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.textMuted)
                    .lineLimit(1)
            }

            if let volume = state.volume {
                VolumeReadout(volume: volume)
            }

            if state.showsPower {
                KeyButton(key: .power, size: 32)
                    .frame(width: 40)
            }

            Button(intent: EndRemoteSessionIntent()) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.surfaceRaised))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close the Lock Screen remote")
        }
    }
}

struct VolumeReadout: View {
    let volume: RemoteActivityAttributes.Volume

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: volume.muted ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 10))
                .foregroundStyle(Color.textMuted)
            Capsule()
                .fill(Color.surfaceInset)
                .frame(width: 44, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(volume.muted ? Color.textMuted : Color.accentText)
                        .frame(width: 44 * volume.fraction, height: 4)
                }
        }
    }
}
