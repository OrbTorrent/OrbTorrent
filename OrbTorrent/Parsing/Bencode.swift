import Foundation

/// A decoded bencoded value, as used by `.torrent` files.
indirect enum BencodeValue: Sendable {
    case integer(Int64)
    case bytes(Data)
    case list([BencodeValue])
    case dictionary([(key: Data, value: BencodeValue)])

    subscript(key: String) -> BencodeValue? {
        guard case .dictionary(let entries) = self else { return nil }
        let keyData = Data(key.utf8)
        return entries.first(where: { $0.key == keyData })?.value
    }

    var integer: Int64? {
        if case .integer(let value) = self { return value }
        return nil
    }

    var data: Data? {
        if case .bytes(let value) = self { return value }
        return nil
    }

    var string: String? {
        data.flatMap { String(data: $0, encoding: .utf8) }
    }

    var list: [BencodeValue]? {
        if case .list(let value) = self { return value }
        return nil
    }

    var entries: [(key: Data, value: BencodeValue)]? {
        if case .dictionary(let value) = self { return value }
        return nil
    }
}

extension BencodeValue {
    static func text(_ text: String) -> BencodeValue { .bytes(Data(text.utf8)) }

    static func dict(_ entries: [String: BencodeValue]) -> BencodeValue {
        .dictionary(entries.map { (key: Data($0.key.utf8), value: $0.value) })
    }

    /// The value in bencode, with each dictionary's keys sorted as the format requires.
    var encoded: Data {
        var data = Data()
        encode(into: &data)
        return data
    }

    private func encode(into data: inout Data) {
        switch self {
        case .integer(let value):
            data.append(contentsOf: Array("i\(value)e".utf8))
        case .bytes(let bytes):
            data.append(contentsOf: Array("\(bytes.count):".utf8))
            data.append(bytes)
        case .list(let items):
            data.append(UInt8(ascii: "l"))
            for item in items { item.encode(into: &data) }
            data.append(UInt8(ascii: "e"))
        case .dictionary(let entries):
            data.append(UInt8(ascii: "d"))
            for entry in entries.sorted(by: { $0.key.lexicographicallyPrecedes($1.key) }) {
                BencodeValue.bytes(entry.key).encode(into: &data)
                entry.value.encode(into: &data)
            }
            data.append(UInt8(ascii: "e"))
        }
    }
}

enum BencodeError: Error {
    case unexpectedEnd
    case invalidToken(offset: Int)
    case invalidInteger(offset: Int)
    case invalidLength(offset: Int)
}

/// A small bencode decoder that also records the byte range of the
/// top-level `info` dictionary, which is needed to compute the info hash.
struct BencodeDecoder {
    private let bytes: [UInt8]
    private var offset = 0
    private var depth = 0
    private(set) var infoRange: Range<Int>?

    init(data: Data) {
        bytes = [UInt8](data)
    }

    mutating func decode() throws -> BencodeValue {
        try decodeValue()
    }

    private mutating func decodeValue() throws -> BencodeValue {
        guard offset < bytes.count else { throw BencodeError.unexpectedEnd }
        switch bytes[offset] {
        case UInt8(ascii: "i"):
            return try decodeInteger()
        case UInt8(ascii: "l"):
            offset += 1
            depth += 1
            defer { depth -= 1 }
            var items: [BencodeValue] = []
            while try peek() != UInt8(ascii: "e") {
                items.append(try decodeValue())
            }
            offset += 1
            return .list(items)
        case UInt8(ascii: "d"):
            offset += 1
            depth += 1
            defer { depth -= 1 }
            var entries: [(key: Data, value: BencodeValue)] = []
            while try peek() != UInt8(ascii: "e") {
                guard case .bytes(let key) = try decodeBytes() else {
                    throw BencodeError.invalidToken(offset: offset)
                }
                let valueStart = offset
                let value = try decodeValue()
                if depth == 1, key == Data("info".utf8) {
                    infoRange = valueStart..<offset
                }
                entries.append((key, value))
            }
            offset += 1
            return .dictionary(entries)
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return try decodeBytes()
        default:
            throw BencodeError.invalidToken(offset: offset)
        }
    }

    private func peek() throws -> UInt8 {
        guard offset < bytes.count else { throw BencodeError.unexpectedEnd }
        return bytes[offset]
    }

    private mutating func decodeInteger() throws -> BencodeValue {
        let start = offset
        offset += 1
        guard let end = bytes[offset...].firstIndex(of: UInt8(ascii: "e")),
              let text = String(bytes: bytes[offset..<end], encoding: .ascii),
              let value = Int64(text)
        else { throw BencodeError.invalidInteger(offset: start) }
        offset = end + 1
        return .integer(value)
    }

    private mutating func decodeBytes() throws -> BencodeValue {
        let start = offset
        guard let colon = bytes[offset...].firstIndex(of: UInt8(ascii: ":")),
              let text = String(bytes: bytes[offset..<colon], encoding: .ascii),
              let length = Int(text), length >= 0
        else { throw BencodeError.invalidLength(offset: start) }
        let dataStart = colon + 1
        guard dataStart + length <= bytes.count else { throw BencodeError.unexpectedEnd }
        offset = dataStart + length
        return .bytes(Data(bytes[dataStart..<offset]))
    }
}
