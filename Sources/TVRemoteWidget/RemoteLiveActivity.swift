import ActivityKit
import SwiftUI
import TVRemoteCore
import WidgetKit

struct RemoteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RemoteActivityAttributes.self) { context in
            RemoteActivityBody(state: context.state)
                .padding(8)
                .background(Color.background)
                .activityBackgroundTint(Color.background)
                .activitySystemActionForegroundColor(Color.accentText)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DPadCluster(size: 30)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 5) {
                        KeyButton(key: .volumeUp, size: 30)
                        KeyButton(key: .volumeDown, size: 30)
                        KeyButton(key: .volumeMute, size: 30)
                    }
                    .frame(width: 54)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 5) {
                        KeyButton(key: .back, size: 30)
                        KeyButton(key: .home, size: 30)
                        KeyButton(key: .playPause, size: 30)
                        ForEach(Macro.lockScreen) { macro in
                            MacroButton(macro: macro, size: 30)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "tv")
                    .foregroundStyle(Color.accentText)
            } compactTrailing: {
                ConnectionDot(state: context.state)
            } minimal: {
                ConnectionDot(state: context.state)
            }
        }
        // Puts the same remote in the Apple Watch Smart Stack and on the CarPlay
        // home screen, with no Watch app to build or install.
        .supplementalActivityFamilies([.small])
    }
}

/// Picks a layout for wherever the activity happens to be rendering: the full
/// grid on the Lock Screen and in StandBy, a thumb-sized cluster on the Watch
/// and in CarPlay.
struct RemoteActivityBody: View {
    let state: RemoteActivityAttributes.ContentState

    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small: SmallRemote(state: state)
        default: LockScreenRemote(state: state)
        }
    }
}

/// Watch and CarPlay. Room for the pad and nothing else, so everything that is
/// not navigation is dropped rather than shrunk into uselessness.
struct SmallRemote: View {
    let state: RemoteActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            DPadCluster(size: 26)
            VStack(spacing: 4) {
                KeyButton(key: .volumeUp, size: 24)
                KeyButton(key: .playPause, size: 24)
                KeyButton(key: .volumeDown, size: 24)
            }
            .frame(width: 40)
        }
    }
}

/// The Lock Screen card.
///
/// Ten controls in two rows rather than eighteen in three. The card gets about
/// 160pt of height, and the previous 6 x 3 grid spent it on 30pt buttons that
/// were below a usable tap target — accurate to hit only by luck. Fewer, bigger
/// controls is the whole design here; the macros and the rest live in the app
/// and in the Dynamic Island's expanded view, where there is room for them.
struct LockScreenRemote: View {
    let state: RemoteActivityAttributes.ContentState

    /// Comfortably above the 44pt Apple asks for on a touch target.
    private let unit: CGFloat = 46
    private let gap: CGFloat = 6

    var body: some View {
        VStack(spacing: 6) {
            ActivityHeader(state: state)

            // Up and down flank the horizontal triple, so left/OK/right keep
            // their spatial sense even without a full cross.
            HStack(spacing: gap) {
                KeyButton(key: .up, size: unit)
                KeyButton(key: .left, size: unit)
                KeyButton(key: .ok, size: unit, emphasised: true)
                KeyButton(key: .right, size: unit)
                KeyButton(key: .down, size: unit)
            }
            HStack(spacing: gap) {
                KeyButton(key: .back, size: unit)
                KeyButton(key: .home, size: unit)
                KeyButton(key: .playPause, size: unit)
                KeyButton(key: .volumeDown, size: unit)
                KeyButton(key: .volumeUp, size: unit)
            }
        }
    }
}

/// The d-pad on its own, for the Dynamic Island's narrower leading region.
struct DPadCluster: View {
    var size: CGFloat = 30

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ControlGap(size: size)
                KeyButton(key: .up, size: size)
                ControlGap(size: size)
            }
            HStack(spacing: 5) {
                KeyButton(key: .left, size: size)
                KeyButton(key: .ok, size: size, emphasised: true)
                KeyButton(key: .right, size: size)
            }
            HStack(spacing: 5) {
                ControlGap(size: size)
                KeyButton(key: .down, size: size)
                ControlGap(size: size)
            }
        }
        .frame(width: 118)
    }
}
