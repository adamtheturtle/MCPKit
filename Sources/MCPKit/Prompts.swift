//
//  Prompts.swift
//  MCPKit
//
//  Generic scaffolding for MCP prompts. Prompts are pre-written, argument-driven
//  instruction templates a client can offer as slash-commands. The catalog and the
//  rendered text are app-specific (they name the app's tools), but the error type and the
//  argument-reading helpers are not, so they live here for every host app's `getPrompt` to
//  reuse.
//

import Foundation
import MCP

/// Raised when a prompt can't be rendered. A host's `MCPToolProvider.getPrompt` throws
/// these and `MCPServer` maps them to JSON-RPC `invalidParams` errors.
public enum PromptError: Swift.Error, Equatable {
    case unknownPrompt(String)
    case missingArgument(String)
    case invalidArgument(name: String, reason: String)
}

/// Raised when a resource can't be read. A host's `MCPToolProvider.readResource` throws
/// these and `MCPServer` maps them to JSON-RPC `invalidParams` errors.
public enum ResourceError: Swift.Error, Equatable {
    case unknownResource(String)
    case invalidURI(String)
    case readFailed(uri: String, reason: String)
}

/// The largest prompt argument these helpers return, measured as UTF-8 bytes.
public let maximumPromptArgumentUTF8Length = 16 * 1_024

private enum PromptArgumentValidation {
    case missing
    case invalid(String)
    case valid(String)
}

private func validatePromptArgument(_ arguments: [String: String]?, _ key: String) -> PromptArgumentValidation {
    guard let raw = arguments?[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
    else { return .missing }

    guard raw.utf8.count <= maximumPromptArgumentUTF8Length else {
        return .invalid("must be at most \(maximumPromptArgumentUTF8Length) UTF-8 bytes")
    }
    guard !raw.unicodeScalars.contains(where: { $0.properties.generalCategory == .format }) else {
        return .invalid("must not contain Unicode format controls")
    }
    return .valid(raw)
}

/// A trimmed, non-empty, bounded value for `key` in a prompt's arguments, or nil when
/// absent or unsafe. Unicode format controls are rejected so bidi overrides and invisible
/// separators cannot be interpolated into rendered prompts or diagnostics.
///
/// Prefer ``optionalPromptArgument(_:_:)`` for optional fields: this helper collapses
/// invalid-present values into `nil`, which silently drops requested constraints.
public func promptArgument(_ arguments: [String: String]?, _ key: String) -> String? {
    guard case let .valid(value) = validatePromptArgument(arguments, key) else { return nil }

    return value
}

/// An optional prompt argument that allows true absence while rejecting invalid-present
/// values (oversized or Unicode format controls).
public func optionalPromptArgument(_ arguments: [String: String]?, _ key: String) throws -> String? {
    switch validatePromptArgument(arguments, key) {
    case .missing:
        return nil
    case let .invalid(reason):
        throw PromptError.invalidArgument(name: key, reason: reason)
    case let .valid(value):
        return value
    }
}

/// A single required prompt argument, distinguishing an absent value from an unsafe one.
public func requiredPromptArgument(_ arguments: [String: String]?, _ key: String) throws -> String {
    switch validatePromptArgument(arguments, key) {
    case .missing:
        throw PromptError.missingArgument(key)
    case let .invalid(reason):
        throw PromptError.invalidArgument(name: key, reason: reason)
    case let .valid(value):
        return value
    }
}

/// A user-role text message, the common building block of a rendered prompt.
public func userPromptMessage(_ text: String) -> Prompt.Message {
    .user(.text(text: text))
}
