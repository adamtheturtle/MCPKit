//
//  PromptTests.swift
//  MCPKitTests
//
//  Exercises prompt argument normalization, validation, and error reporting.
//

@testable import MCPKit
import Testing

@Suite("Prompt helpers")
struct PromptHelperTests {
    @Test
    func `promptArgument trims and nils empties`() {
        #expect(promptArgument(["t": "  hi  "], "t") == "hi")
        #expect(promptArgument(["t": "   "], "t") == nil)
        #expect(promptArgument(nil, "t") == nil)
    }

    @Test
    func `requiredPromptArgument throws for an absent argument`() throws {
        #expect(try requiredPromptArgument(["t": "x"], "t") == "x")
        #expect(throws: PromptError.missingArgument("t")) {
            try requiredPromptArgument([:], "t")
        }
    }

    @Test
    func `prompt arguments reject oversized values and Unicode format controls`() {
        let oversized = String(repeating: "a", count: maximumPromptArgumentUTF8Length + 1)
        #expect(promptArgument(["value": oversized], "value") == nil)
        #expect(throws: PromptError.invalidArgument(
            name: "value",
            reason: "must be at most \(maximumPromptArgumentUTF8Length) UTF-8 bytes"
        )) {
            try requiredPromptArgument(["value": oversized], "value")
        }
        #expect(throws: PromptError.invalidArgument(
            name: "value",
            reason: "must be at most \(maximumPromptArgumentUTF8Length) UTF-8 bytes"
        )) {
            try optionalPromptArgument(["value": oversized], "value")
        }

        for value in ["left\u{202E}right", "isolated\u{2066}text", "zero\u{200B}width"] {
            #expect(promptArgument(["value": value], "value") == nil)
            #expect(throws: PromptError.invalidArgument(
                name: "value",
                reason: "must not contain Unicode format controls"
            )) {
                try requiredPromptArgument(["value": value], "value")
            }
            #expect(throws: PromptError.invalidArgument(
                name: "value",
                reason: "must not contain Unicode format controls"
            )) {
                try optionalPromptArgument(["value": value], "value")
            }
        }
    }

    @Test
    func `optionalPromptArgument allows absence and returns valid values`() throws {
        #expect(try optionalPromptArgument(nil, "t") == nil)
        #expect(try optionalPromptArgument([:], "t") == nil)
        #expect(try optionalPromptArgument(["t": "   "], "t") == nil)
        #expect(try optionalPromptArgument(["t": "  hi  "], "t") == "hi")
    }

    @Test
    func `prompt errors describe invalid values`() {
        let error = PromptError.invalidArgument(name: "pad_id", reason: "must be a safe identifier")
        #expect(error == .invalidArgument(name: "pad_id", reason: "must be a safe identifier"))
    }
}
