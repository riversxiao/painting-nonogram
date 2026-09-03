import Foundation

public enum CanonicalJSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case string(String)
    case array([CanonicalJSONValue])
    case object([String: CanonicalJSONValue])
}

public enum CanonicalJSON {
    public static func data(_ value: CanonicalJSONValue) -> Data {
        Data(string(value).utf8)
    }

    public static func string(_ value: CanonicalJSONValue) -> String {
        switch value {
        case .null:
            return "null"
        case .bool(let value):
            return value ? "true" : "false"
        case .integer(let value):
            return String(value)
        case .string(let value):
            return quoted(value)
        case .array(let values):
            return "[" + values.map(string).joined(separator: ",") + "]"
        case .object(let object):
            return "{" + object.keys.sorted().map { key in
                quoted(key) + ":" + string(object[key]!)
            }.joined(separator: ",") + "}"
        }
    }

    private static func quoted(_ value: String) -> String {
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
            case 0x00...0x1F:
                result += String(format: "\\u%04x", scalar.value)
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        result += "\""
        return result
    }
}
