import Foundation

/// A JSON value, for what extensions send and receive.
enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Converts what `JSONSerialization` produces.
    init(_ any: Any?) {
        switch any {
        case nil, is NSNull: self = .null
        case let number as NSNumber:
            // JSONSerialization gives booleans as NSNumber too.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case let string as String: self = .string(string)
        case let array as [Any]: self = .array(array.map { JSONValue($0) })
        case let object as [String: Any]: self = .object(object.mapValues { JSONValue($0) })
        default: self = .null
        }
    }

    init(data: Data) throws {
        self.init(try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
    }

    /// What `JSONSerialization` accepts.
    var any: Any {
        switch self {
        case .null: NSNull()
        case .bool(let value): value
        case .number(let value): value
        case .string(let value): value
        case .array(let values): values.map(\.any)
        case .object(let values): values.mapValues(\.any)
        }
    }

    func data() -> Data {
        (try? JSONSerialization.data(withJSONObject: any, options: [.fragmentsAllowed, .sortedKeys])) ?? Data("null".utf8)
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let values) = self { return values[key] }
        return nil
    }

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var double: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var int: Int? {
        guard let double, double.isFinite, double.rounded() == double, abs(double) < 9e15 else { return nil }
        return Int(double)
    }

    var bool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var array: [JSONValue]? {
        if case .array(let values) = self { return values }
        return nil
    }

    var object: [String: JSONValue]? {
        if case .object(let values) = self { return values }
        return nil
    }

    var isNull: Bool { self == .null }
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let values): try container.encode(values)
        case .object(let values): try container.encode(values)
        }
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { $1 }))
    }
    init(nilLiteral: ()) { self = .null }
}

extension JSONValue: ExpressibleByStringInterpolation {
    init(stringInterpolation: DefaultStringInterpolation) {
        self = .string(String(stringInterpolation: stringInterpolation))
    }
}
