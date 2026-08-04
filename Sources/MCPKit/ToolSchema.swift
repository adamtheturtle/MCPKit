//
//  ToolSchema.swift
//  MCPKit
//
//  Converts a host app's plumbing-neutral tool catalog - plain JSON descriptors
//  (`[String: Any]`) - into the swift-sdk's `Tool`/`Value` types. Keeping the catalog
//  as JSON lets an app define its tools once (names, descriptions, input schemas,
//  annotations) in a Foundation-only core and advertise the exact same list from both
//  an in-app server and a standalone CLI. This file is the generic descriptor->`Tool`
//  bridge; the catalog content itself stays app-side.
//

import CoreFoundation
import Foundation
import MCP

/// Converts a JSON value from a catalog into an MCP `Value`. Order matters: `Bool` is
/// checked before the numeric types so a flag isn't read as an int. An already-built
/// `Value` passes through unchanged.
public func mcpValue(_ any: Any) -> Value {
    switch any {
    case let value as Value: value
    case let number as NSNumber: mcpNumber(number)
    case let bool as Bool: .bool(bool)
    case let int as Int: .int(int)
    case let double as Double: .double(double)
    case let string as String: .string(string)
    case let array as [Any]: .array(array.map(mcpValue))
    case let object as [String: Any]: .object(object.mapValues(mcpValue))
    default: .null
    }
}

private func mcpNumber(_ number: NSNumber) -> Value {
    guard CFGetTypeID(number) != CFBooleanGetTypeID() else {
        return .bool(number.boolValue)
    }

    switch String(cString: number.objCType) {
    case "c", "s", "i", "l", "q":
        let value = number.int64Value
        return Int(exactly: value).map(Value.int) ?? .double(number.doubleValue)
    case "C", "S", "I", "L", "Q":
        let value = number.uint64Value
        return Int(exactly: value).map(Value.int) ?? .double(number.doubleValue)
    default:
        return .double(number.doubleValue)
    }
}

/// Turns one descriptor (`{ name, description, inputSchema, annotations? }`) into an
/// `MCP.Tool`. Returns nil when `name` is missing, mistyped, or blank. A missing
/// description or input schema still receives a harmless default.
public func mcpTool(from descriptor: [String: Any]) -> Tool? {
    guard let rawName = descriptor["name"] as? String else { return nil }
    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }
    let description = descriptor["description"] as? String ?? ""
    let inputSchema = mcpValue(descriptor["inputSchema"] ?? [String: Any]())
    let annotations = (descriptor["annotations"] as? [String: Any]).map(mcpAnnotations)
        ?? Tool.Annotations()
    return Tool(name: name, description: description, inputSchema: inputSchema, annotations: annotations)
}

/// Builds `Tool.Annotations` from a descriptor's `annotations` sub-object.
public func mcpAnnotations(_ dict: [String: Any]) -> Tool.Annotations {
    Tool.Annotations(
        title: dict["title"] as? String,
        readOnlyHint: dict["readOnlyHint"] as? Bool,
        destructiveHint: dict["destructiveHint"] as? Bool,
        openWorldHint: dict["openWorldHint"] as? Bool
    )
}

/// Converts a whole catalog of JSON descriptors into the `Tool` list to advertise from
/// `tools/list`.
public func mcpTools(from descriptors: [[String: Any]]) -> [Tool] {
    descriptors.compactMap(mcpTool)
}
