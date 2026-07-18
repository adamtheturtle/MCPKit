//
//  Arguments.swift
//  MCPKit
//
//  Coercion helpers for tool-call arguments. MCP clients are loosely typed - a numeric id
//  can arrive as an int, a double, or a string - so these accept any reasonable encoding
//  rather than failing on a type mismatch. Service-agnostic: every host app coerces its
//  tool arguments the same way.
//

import Foundation
import MCP

/// A string argument, coercing ints/doubles to their textual form. Returns nil when
/// the key is absent or holds a non-scalar value.
public func stringArgument(_ arguments: [String: Value]?, _ key: String) -> String? {
    switch arguments?[key] {
    case let .string(value): value
    case let .int(value): String(value)
    case let .double(value): String(value)
    default: nil
    }
}

/// An integer argument, coercing doubles (truncating toward zero) and numeric strings.
/// Returns nil when the key is absent or can't be read as an integer - which includes a
/// value outside `Int`'s range and a non-finite one, so a hostile or sloppy client can't
/// bring the server down with a number.
public func intArgument(_ arguments: [String: Value]?, _ key: String) -> Int? {
    switch arguments?[key] {
    case let .int(value): value
    case let .double(value): truncatedInt(value)
    // A numeric string may still carry a fraction or an out-of-range magnitude, so fall
    // back to the same double coercion rather than reading only exact integer literals.
    case let .string(value): Int(value) ?? Double(value).flatMap(truncatedInt)
    default: nil
    }
}

/// `value` truncated toward zero, or nil when that isn't an `Int` - out of range, NaN, or
/// infinite. `Int(_: Double)` *traps* on all three, and the SDK's decoder hands any JSON
/// number too large for `Int` to us as a `.double`, so every conversion goes through
/// `Int(exactly:)` instead.
private func truncatedInt(_ value: Double) -> Int? {
    Int(exactly: value.rounded(.towardZero))
}

/// A trimmed, non-empty string argument, or nil - so empty strings don't get sent as
/// real values in write bodies.
public func optionalString(_ arguments: [String: Value]?, _ key: String) -> String? {
    guard let value = stringArgument(arguments, key)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty
    else { return nil }

    return value
}
