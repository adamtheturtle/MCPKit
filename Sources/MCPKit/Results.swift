//
//  Results.swift
//  MCPKit
//
//  Generic `CallTool.Result` builders shared by every host app's tool dispatch. They wrap
//  the swift-sdk's verbose content-enum initializers (`.text(text:annotations:_meta:)`) so
//  dispatch code reads cleanly.
//

import Foundation
import MCP

/// A plain-text tool result. `isError` nil marks success; pass `true` to flag a
/// tool-level error the client should surface.
///
/// NUL bytes are rejected: they are valid in a Swift `String` but break JSON and stdio
/// framing. Pass `Data` through ``textResult(utf8:isError:)`` when the payload may not be
/// well-formed UTF-8.
public func textResult(_ text: String, isError: Bool? = nil) -> CallTool.Result {
    guard !text.unicodeScalars.contains(where: { $0.value == 0 }) else {
        return CallTool.Result(
            content: [.text(text: "Tool output contained a NUL byte.", annotations: nil, _meta: nil)],
            isError: true
        )
    }
    return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: isError)
}

/// Decodes `data` as UTF-8 and returns a text tool result, or an error result when the
/// bytes are not valid UTF-8.
public func textResult(utf8 data: Data, isError: Bool? = nil) -> CallTool.Result {
    guard let text = String(data: data, encoding: .utf8) else {
        return errorResult("Tool output is not valid UTF-8.")
    }
    return textResult(text, isError: isError)
}

/// An error tool result carrying `message`.
public func errorResult(_ message: String) -> CallTool.Result {
    textResult(message, isError: true)
}

/// The standard "missing required argument" error result.
public func missingArgument(_ name: String) -> CallTool.Result {
    errorResult("Missing required argument: \(name)")
}

/// Encodes a result dictionary as pretty, key-sorted JSON text, or an error result when
/// it can't be serialized.
public func jsonResult(_ object: [String: Any]) -> CallTool.Result {
    // `JSONSerialization.data(withJSONObject:)` raises an Objective-C `NSException` -
    // which no Swift `catch` can see - for contents JSON can't express, such as
    // `Double.nan`, a `Date`, or a `URL`. Validating first is what makes the error
    // result below reachable instead of aborting the process.
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(
              withJSONObject: object, options: [.prettyPrinted, .sortedKeys]
          ) else {
        return errorResult("Could not encode the result.")
    }

    return textResult(utf8: data)
}
