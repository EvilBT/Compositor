import Foundation

/// Arbitrary JSON, preserved losslessly.
///
/// Exists for one reason: a document written by a newer build must survive a round trip
/// through an older one. When a device meets a retouch op it does not recognize, it keeps
/// the op's payload verbatim in `JSONValue` and writes it back unchanged on save.
///
/// The alternative — refusing the file, as Compositor's `.comp` loader does when
/// `version > ProjectManifest.current` — is defensible for a single-user desktop app.
/// It is not defensible for one document synced across a phone, a tablet and a Mac that
/// update on their own schedules: the oldest device would destroy the newest device's work.
///
/// `floatLiteral` etc. are intentionally absent: this type is only ever decoded and
/// encoded, never written by hand.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        // Order matters: a JSON `true` also decodes as `Int` on some paths, and a whole
        // number must not silently become a Double (it would re-encode as `1.0`).
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognized JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

// Convenience accessors, for the MCP layer and for tests.
extension JSONValue {
    public var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    public var doubleValue: Double? {
        switch self {
        case .int(let v): return Double(v)
        case .double(let v): return v
        default: return nil
        }
    }

    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}
