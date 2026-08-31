import Foundation

enum ProtoValue: Equatable {
    case varint(UInt64)
    case bytes([UInt8])
    case fixed32(UInt32)
    case fixed64(UInt64)

    var uint: UInt64? {
        if case let .varint(value) = self { return value }
        return nil
    }

    var bool: Bool? { uint.map { $0 != 0 } }

    var string: String? {
        if case let .bytes(raw) = self { return String(decoding: raw, as: UTF8.self) }
        return nil
    }

    var message: ProtoMessage? {
        if case let .bytes(raw) = self { return ProtoMessage(decoding: raw) }
        return nil
    }
}

struct ProtoMessage {
    private(set) var fields: [Int: [ProtoValue]] = [:]

    init() {}

    init?(decoding bytes: [UInt8]) {
        var index = 0
        while index < bytes.count {
            guard let (key, keyWidth) = Protobuf.decodeVarint(bytes, at: index) else { return nil }
            index += keyWidth
            let field = Int(key >> 3)
            guard field > 0 else { return nil }

            switch key & 0x07 {
            case 0:
                guard let (value, width) = Protobuf.decodeVarint(bytes, at: index) else { return nil }
                index += width
                append(.varint(value), to: field)
            case 1:
                guard index + 8 <= bytes.count else { return nil }
                var value: UInt64 = 0
                for offset in (0..<8).reversed() { value = value << 8 | UInt64(bytes[index + offset]) }
                index += 8
                append(.fixed64(value), to: field)
            case 2:
                guard let (length, width) = Protobuf.decodeVarint(bytes, at: index) else { return nil }
                index += width
                let end = index + Int(length)
                guard end <= bytes.count else { return nil }
                append(.bytes(Array(bytes[index..<end])), to: field)
                index = end
            case 5:
                guard index + 4 <= bytes.count else { return nil }
                var value: UInt32 = 0
                for offset in (0..<4).reversed() { value = value << 8 | UInt32(bytes[index + offset]) }
                index += 4
                append(.fixed32(value), to: field)
            default:
                return nil
            }
        }
    }

    subscript(field: Int) -> ProtoValue? { fields[field]?.first }

    var isEmpty: Bool { fields.isEmpty }

    private mutating func append(_ value: ProtoValue, to field: Int) {
        fields[field, default: []].append(value)
    }
}

enum Protobuf {
    static func varint(_ value: UInt64) -> [UInt8] {
        var remaining = value
        var out: [UInt8] = []
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            out.append(byte)
        } while remaining != 0
        return out
    }

    static func decodeVarint(_ bytes: [UInt8], at start: Int) -> (value: UInt64, width: Int)? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var index = start
        while index < bytes.count {
            let byte = bytes[index]
            guard shift <= 63 else { return nil }
            value |= UInt64(byte & 0x7F) << shift
            index += 1
            if byte & 0x80 == 0 { return (value, index - start) }
            shift += 7
        }
        return nil
    }

    static func varintField(_ field: Int, _ value: UInt64) -> [UInt8] {
        varint(UInt64(field) << 3) + varint(value)
    }

    static func boolField(_ field: Int, _ value: Bool) -> [UInt8] {
        varintField(field, value ? 1 : 0)
    }

    /// A varint field, omitted entirely when the value is zero.
    ///
    /// proto3 does not serialise default-valued scalars, so a real encoder emits
    /// nothing for `0`. The TV distinguishes an absent field from one explicitly
    /// set to zero, so writing the zero produces a message it silently ignores.
    static func varintFieldSkippingZero(_ field: Int, _ value: UInt64) -> [UInt8] {
        value == 0 ? [] : varintField(field, value)
    }

    static func bytesField(_ field: Int, _ payload: [UInt8]) -> [UInt8] {
        varint(UInt64(field) << 3 | 2) + varint(UInt64(payload.count)) + payload
    }

    static func stringField(_ field: Int, _ value: String) -> [UInt8] {
        bytesField(field, Array(value.utf8))
    }

    static func lengthPrefixed(_ payload: [UInt8]) -> [UInt8] {
        varint(UInt64(payload.count)) + payload
    }
}
