public enum RemoteKey: String, CaseIterable, Sendable {
    case up, down, left, right, ok, back, home, playPause, volumeUp, volumeDown
    case volumeMute, tvInputHDMI1
    case rewind, fastForward, previous, next, power

    /// SF Symbol for the key. Lives here rather than in a view because the Live
    /// Activity is rendered by WidgetKit in another process and cannot reach app assets.
    public var symbol: String {
        switch self {
        case .up: "chevron.up"
        case .down: "chevron.down"
        case .left: "chevron.left"
        case .right: "chevron.right"
        case .ok: "circle"
        case .back: "arrow.uturn.backward"
        case .home: "house"
        case .playPause: "playpause"
        case .volumeUp: "speaker.wave.2"
        case .volumeDown: "speaker.wave.1"
        case .volumeMute: "speaker.slash"
        case .tvInputHDMI1: "gamecontroller"
        case .rewind: "backward"
        case .fastForward: "forward"
        case .previous: "backward.end"
        case .next: "forward.end"
        case .power: "power"
        }
    }

    public var label: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .ok: "OK"
        case .back: "Back"
        case .home: "Home"
        case .playPause: "Play or pause"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .volumeMute: "Mute"
        case .tvInputHDMI1: "HDMI 1"
        case .rewind: "Rewind"
        case .fastForward: "Fast forward"
        case .previous: "Previous"
        case .next: "Next"
        case .power: "Power"
        }
    }
}
