import SwiftUI

extension Color {
    public static let background = Color(hex: 0x0E1013)
    public static let surfaceRaised = Color(hex: 0x1A1D22)
    public static let surfaceInset = Color(hex: 0x24282E)
    public static let textPrimary = Color(hex: 0xEDEFF2)
    public static let textSecondary = Color(hex: 0x8A9099)
    public static let textMuted = Color(hex: 0x5C626B)
    public static let accentWash = Color(hex: 0x12312A)
    public static let accentText = Color(hex: 0x5DCAA5)
    public static let statusOK = Color(hex: 0x3ECF8E)
    public static let statusSimulated = Color(hex: 0xE0A33E)
    public static let hairline = Color.white.opacity(0.08)

    private init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
