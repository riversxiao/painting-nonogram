import Foundation

public enum JCSCanonicalizationError: Error, Equatable, CustomStringConvertible {
    case topLevelObjectRequired
    case missingExcludedField(String)
    case unsupportedValue(String)

    public var description: String {
        switch self {
        case .topLevelObjectRequired: "JCS document must be a top-level JSON object"
        case .missingExcludedField(let field): "JCS document is missing top-level field \(field)"
        case .unsupportedValue(let reason): "JCS cannot encode value: \(reason)"
        }
    }
}

/// RFC 8785 JSON Canonicalization Scheme for I-JSON documents.
public enum JCSCanonicalizer {
    public static func canonicalData(
        _ data: Data,
        removingTopLevelField field: String
    ) throws -> Data {
        var value = try JCSParser.parse(data)
        guard case .object(var members) = value else {
            throw JCSCanonicalizationError.topLevelObjectRequired
        }
        let fieldBytes = Array(field.utf8)
        guard let excludedIndex = members.firstIndex(where: {
            Array($0.name.utf8) == fieldBytes
        }) else {
            throw JCSCanonicalizationError.missingExcludedField(field)
        }
        members.remove(at: excludedIndex)
        value = .object(members)
        return Data(try encode(value).utf8)
    }

    private static func encode(_ value: JCSValue) throws -> String {
        switch value {
        case .null: return "null"
        case .boolean(let value): return value ? "true" : "false"
        case .string(let value): return quote(value)
        case .number(let value): return try canonicalNumber(value)
        case .array(let values):
            return "[" + (try values.map(encode)).joined(separator: ",") + "]"
        case .object(let members):
            let ordered = members.sorted { lhs, rhs in
                Array(lhs.name.utf16).lexicographicallyPrecedes(Array(rhs.name.utf16))
            }
            return "{" + (try ordered.map { member in
                quote(member.name) + ":" + (try encode(member.value))
            }).joined(separator: ",") + "}"
        }
    }

    /// Swift's `String(Double)` supplies shortest round-trippable IEEE-754 digits. This applies
    /// ECMAScript's fixed/scientific formatting thresholds required by RFC 8785 section 3.2.2.3.
    private static func canonicalNumber(_ value: Double) throws -> String {
        guard value.isFinite else {
            throw JCSCanonicalizationError.unsupportedValue("non-finite number")
        }
        if value == 0 { return "0" }

        let negative = value < 0
        let raw = String(negative ? -value : value).lowercased()
        let components = raw.split(separator: "e", omittingEmptySubsequences: false)
        guard components.count <= 2 else {
            throw JCSCanonicalizationError.unsupportedValue("number serialization")
        }
        let mantissa = String(components[0])
        let explicitExponent = components.count == 2 ? Int(components[1]) : 0
        guard let explicitExponent else {
            throw JCSCanonicalizationError.unsupportedValue("number exponent")
        }

        let decimalIndex = mantissa.firstIndex(of: ".")
        let integerDigitCount = decimalIndex.map { mantissa.distance(from: mantissa.startIndex, to: $0) }
            ?? mantissa.count
        var digits = mantissa.filter { $0 != "." }
        var decimalPosition = integerDigitCount + explicitExponent
        while digits.first == "0" {
            digits.removeFirst()
            decimalPosition -= 1
        }
        while digits.last == "0" { digits.removeLast() }
        guard !digits.isEmpty else { return "0" }

        let k = digits.count
        let body: String
        if k <= decimalPosition, decimalPosition <= 21 {
            body = digits + String(repeating: "0", count: decimalPosition - k)
        } else if 0 < decimalPosition, decimalPosition <= 21 {
            let split = digits.index(digits.startIndex, offsetBy: decimalPosition)
            body = String(digits[..<split]) + "." + String(digits[split...])
        } else if -6 < decimalPosition, decimalPosition <= 0 {
            body = "0." + String(repeating: "0", count: -decimalPosition) + digits
        } else {
            let exponent = decimalPosition - 1
            let significand = k == 1
                ? digits
                : String(digits.first!) + "." + String(digits.dropFirst())
            body = significand + "e" + (exponent >= 0 ? "+" : "") + String(exponent)
        }
        return negative ? "-" + body : body
    }

    private static func quote(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08: result += "\\b"
            case 0x09: result += "\\t"
            case 0x0A: result += "\\n"
            case 0x0C: result += "\\f"
            case 0x0D: result += "\\r"
            case 0x22: result += "\\\""
            case 0x5C: result += "\\\\"
            case 0x00...0x1F: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
}

private struct JCSObjectMember {
    let name: String
    let value: JCSValue
}

private indirect enum JCSValue {
    case null
    case boolean(Bool)
    case string(String)
    case number(Double)
    case array([JCSValue])
    case object([JCSObjectMember])
}

/// Parses numbers directly into IEEE-754 doubles so Foundation's platform-specific NSNumber
/// decimal parser/renderer cannot alter canonical identity. Duplicate names are rejected.
private struct JCSParser {
    private let bytes: [UInt8]
    private var index = 0

    static func parse(_ data: Data) throws -> JCSValue {
        var parser = JCSParser(bytes: Array(data))
        let value = try parser.parseValue()
        parser.skipWhitespace()
        guard parser.index == parser.bytes.count else { throw parser.invalid("trailing JSON data") }
        return value
    }

    private mutating func parseValue() throws -> JCSValue {
        skipWhitespace()
        guard index < bytes.count else { throw invalid("unexpected end of JSON") }
        switch bytes[index] {
        case 0x7B: return try parseObject()
        case 0x5B: return try parseArray()
        case 0x22: return .string(try parseString())
        case 0x74: try consume("true"); return .boolean(true)
        case 0x66: try consume("false"); return .boolean(false)
        case 0x6E: try consume("null"); return .null
        default: return .number(try parseNumber())
        }
    }

    private mutating func parseObject() throws -> JCSValue {
        index += 1
        skipWhitespace()
        if consumeIf(0x7D) { return .object([]) }
        var members: [JCSObjectMember] = []
        var exactNames = Set<[UInt8]>()
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == 0x22 else { throw invalid("object member name") }
            let name = try parseString()
            guard exactNames.insert(Array(name.utf8)).inserted else {
                throw invalid("duplicate object member \(name)")
            }
            skipWhitespace()
            guard consumeIf(0x3A) else { throw invalid("missing object colon") }
            members.append(JCSObjectMember(name: name, value: try parseValue()))
            skipWhitespace()
            if consumeIf(0x7D) { return .object(members) }
            guard consumeIf(0x2C) else { throw invalid("missing object comma") }
        }
    }

    private mutating func parseArray() throws -> JCSValue {
        index += 1
        skipWhitespace()
        if consumeIf(0x5D) { return .array([]) }
        var values: [JCSValue] = []
        while true {
            values.append(try parseValue())
            skipWhitespace()
            if consumeIf(0x5D) { return .array(values) }
            guard consumeIf(0x2C) else { throw invalid("missing array comma") }
        }
    }

    private mutating func parseString() throws -> String {
        let start = index
        index += 1
        while index < bytes.count {
            switch bytes[index] {
            case 0x22:
                index += 1
                do { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<index])) }
                catch { throw invalid("invalid JSON string") }
            case 0x5C:
                index += 1
                guard index < bytes.count else { throw invalid("truncated escape") }
                if bytes[index] == 0x75 {
                    guard index + 4 < bytes.count else { throw invalid("truncated Unicode escape") }
                    index += 4
                }
                index += 1
            case 0x00...0x1F: throw invalid("unescaped control character")
            default: index += 1
            }
        }
        throw invalid("unterminated string")
    }

    private mutating func parseNumber() throws -> Double {
        let start = index
        if consumeIf(0x2D), index == bytes.count { throw invalid("truncated number") }

        guard index < bytes.count else { throw invalid("truncated number") }
        if consumeIf(0x30) {
            if index < bytes.count, isDigit(bytes[index]) { throw invalid("leading zero") }
        } else {
            guard isNonzeroDigit(bytes[index]) else { throw invalid("invalid integer") }
            while index < bytes.count, isDigit(bytes[index]) { index += 1 }
        }

        if consumeIf(0x2E) {
            let fractionStart = index
            while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            guard index > fractionStart else { throw invalid("empty fraction") }
        }
        if index < bytes.count, bytes[index] == 0x65 || bytes[index] == 0x45 {
            index += 1
            if index < bytes.count, bytes[index] == 0x2B || bytes[index] == 0x2D { index += 1 }
            let exponentStart = index
            while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            guard index > exponentStart else { throw invalid("empty exponent") }
        }
        if index < bytes.count,
           ![0x20, 0x09, 0x0A, 0x0D, 0x2C, 0x5D, 0x7D].contains(bytes[index]) {
            throw invalid("invalid number delimiter")
        }

        let token = String(bytes: bytes[start..<index], encoding: .utf8)
        guard let token, let value = Double(token), value.isFinite else {
            throw invalid("invalid or non-finite number")
        }
        return value
    }

    private mutating func consume(_ literal: String) throws {
        let expected = Array(literal.utf8)
        guard index + expected.count <= bytes.count,
              Array(bytes[index..<(index + expected.count)]) == expected else {
            throw invalid("invalid literal")
        }
        index += expected.count
    }

    private mutating func consumeIf(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    private mutating func skipWhitespace() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
    }

    private func isDigit(_ byte: UInt8) -> Bool { (0x30...0x39).contains(byte) }
    private func isNonzeroDigit(_ byte: UInt8) -> Bool { (0x31...0x39).contains(byte) }
    private func invalid(_ reason: String) -> JCSCanonicalizationError { .unsupportedValue(reason) }
}
