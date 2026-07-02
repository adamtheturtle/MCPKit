# MCPKit

Batteries-included scaffolding for exposing your Swift app's features as a
[Model Context Protocol](https://modelcontextprotocol.io) server, built on top of the
official [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk).

The SDK gives you the protocol. MCPKit gives you the boring-but-necessary layer around it:
a single protocol to implement, a server bootstrap, a headless `--mcp` stdio entry point,
loosely-typed argument coercion, a JSON-to-`Tool` bridge, result/prompt builders, an
append-only activity log, and the ready-to-paste client config snippets for Claude Desktop,
Claude Code, Codex, and Cursor.

Everything is **service-agnostic** - MCPKit knows nothing about your domain. You implement
one protocol with your own tool catalog and dispatch; MCPKit wires it to the SDK.

[**API documentation**](https://swiftpackageindex.com/adamtheturtle/MCPKit/documentation/mcpkit)

## Installation

Add MCPKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/adamtheturtle/MCPKit.git", from: "0.1.0")
]
```

and depend on the `MCPKit` product from your target.

Supports macOS 13+, iOS 16+, Mac Catalyst 16+, watchOS 9+, tvOS 16+, and visionOS 1+.

## Usage

### 1. Implement a provider

`MCPToolProvider` is the one seam you implement. Only `tools()` and `callTool` are
required; prompts and resources default to empty.

```swift
import MCP
import MCPKit

struct MyProvider: MCPToolProvider {
    func tools() async -> [Tool] {
        // Define your catalog once as plain JSON and let MCPKit build the `Tool` list.
        mcpTools(from: [
            [
                "name": "greet",
                "description": "Greets someone by name.",
                "inputSchema": [
                    "type": "object",
                    "properties": ["name": ["type": "string"]],
                    "required": ["name"]
                ],
                "annotations": ["readOnlyHint": true]
            ]
        ])
    }

    func callTool(_ name: String, arguments: [String: Value]?) async -> CallTool.Result {
        switch name {
        case "greet":
            guard let who = optionalString(arguments, "name") else {
                return missingArgument("name")
            }
            return textResult("Hello, \(who)!")
        default:
            return errorResult("Unknown tool: \(name)")
        }
    }
}
```

### 2. Serve it

In-process (you keep the returned server alive):

```swift
let server = MCPServer(name: "MyApp", version: "1.0", provider: MyProvider())
try await server.start(transport: StdioTransport())
```

Or, from a GUI app's `main`, switch into a headless MCP process when launched with `--mcp`:

```swift
if MCPServer.wantsStdioMCP() {
    MCPServer.runOverStdioUntilExit(name: "MyApp", provider: MyProvider())  // never returns
}
// ...otherwise start your UI as normal.
```

### 3. Tell users how to connect

`MCPClient` produces the exact config block or command each client expects, so your
settings UI doesn't have to hand-roll them:

```swift
for client in MCPClient.allCases {
    print(client.displayName)  // e.g. "Claude Desktop"
    print(client.configPath)   // where it lives
    print(client.configSnippet(command: "/path/to/MyApp", serverName: "myapp"))
}
```

## What's included

| Type / function | Purpose |
| --- | --- |
| `MCPToolProvider` | The protocol your app implements: tools, dispatch, and optional prompts/resources. |
| `MCPServer` | Wires a provider to the SDK; `start`/`run` over any transport. |
| `MCPServer.runOverStdioUntilExit` | Headless `--mcp` stdio entry point for a GUI app's `main`. |
| `mcpTools(from:)` / `mcpTool` / `mcpValue` | Build SDK `Tool`/`Value` types from plain JSON descriptors. |
| `stringArgument` / `intArgument` / `optionalString` | Loosely-typed tool-argument coercion. |
| `textResult` / `errorResult` / `jsonResult` / `missingArgument` | `CallTool.Result` builders. |
| `PromptError` / `promptArgument` / `userPromptMessage` | Prompt scaffolding for `getPrompt`. |
| `JSONLLog` | Append-only, multi-process-tolerant JSONL activity log. |
| `MCPClient` | Config snippets for Claude Desktop, Claude Code, Codex, and Cursor. |

## License

MIT - see [LICENSE](LICENSE).
