import Foundation

/// Android key codes for typeable characters.
///
/// The TV never emits the IME batch edit that `RemoteImeBatchEdit` needs, so text is
/// typed the way a USB keyboard does it: one key event per character. This works in
/// any focused field and needs no negotiation.
enum CharacterKeys {
    static let delete: UInt64 = 67
    static let enter: UInt64 = 66
    static let space: UInt64 = 62

    private static let punctuation: [Character: UInt64] = [
        " ": 62, ".": 56, ",": 55, "-": 69, "@": 77, "/": 76, "'": 75,
    ]

    static func code(for character: Character) -> UInt64? {
        let lowered = Character(character.lowercased())
        if let ascii = lowered.asciiValue {
            switch ascii {
            case 0x61...0x7A: return UInt64(ascii - 0x61) + 29   // a-z -> 29..54
            case 0x30...0x39: return UInt64(ascii - 0x30) + 7    // 0-9 -> 7..16
            default: break
            }
        }
        return punctuation[lowered]
    }

    /// Characters we cannot express as a key event, so the UI can refuse them clearly.
    static func unsupported(in text: String) -> [Character] {
        text.filter { code(for: $0) == nil }
    }
}
