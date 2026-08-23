//
//  main.swift
//  MCPKitExample
//
//  Minimal host demonstrating MCPToolProvider, prompts, and stdio bootstrap.
//  Run with: swift run MCPKitExample --mcp
//

import Foundation
import MCP
import MCPKit

struct ExampleProvider: MCPToolProvider {
    func tools() async -> [Tool] {
        mcpTools(from: [
            [
                "name": "echo",
                "description": "Echoes a message argument.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "message": ["type": "string"]
                    ],
                    "required": ["message"]
                ],
                "annotations": ["title": "Echo", "readOnlyHint": true]
            ]
        ])
    }

    func callTool(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        switch name {
        case "echo":
            guard let message = optionalString(arguments, "message") else {
                return missingArgument("message")
            }
            return textResult(message)
        default:
            return errorResult("Unknown tool: \(name)")
        }
    }

    func prompts() async -> [Prompt] {
        [Prompt(name: "greet", description: "A short greeting.", arguments: [
            .init(name: "name", description: "Who to greet", required: true)
        ])]
    }

    func getPrompt(_ name: String, arguments: [String: String]?) async throws -> GetPrompt.Result {
        guard name == "greet" else { throw PromptError.unknownPrompt(name) }
        let who = try requiredPromptArgument(arguments, "name")
        return GetPrompt.Result(
            description: "Greeting",
            messages: [userPromptMessage("Please greet \(who).")]
        )
    }
}

MCPServer.runOverStdioUntilExit(
    name: "MCPKitExample",
    version: "0.1.0",
    provider: ExampleProvider()
)
