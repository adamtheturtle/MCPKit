//
//  MCPKitTests.swift
//  MCPKitTests
//
//  Exercises the service-agnostic MCP scaffolding: argument coercion, the JSON
//  descriptor -> Tool bridge, the result builders, the prompt helpers, and the
//  MCPToolProvider default implementations. The server bootstrap is thin glue over the
//  SDK; these prove the reusable logic a host app builds on. The JSONL activity log has
//  enough of its own behaviour to warrant a file: see `JSONLLogTests.swift`.
//

import Foundation
import MCP
@testable import MCPKit
import Testing

@Suite("Argument coercion")
struct ArgumentTests {
    @Test
    func `stringArgument coerces ints and doubles and rejects non-scalars`() {
        let args: [String: Value] = ["s": .string("hi"), "i": .int(5), "d": .double(2.5), "a": .array([])]
        #expect(stringArgument(args, "s") == "hi")
        #expect(stringArgument(args, "i") == "5")
        #expect(stringArgument(args, "d") == "2.5")
        #expect(stringArgument(args, "a") == nil)
        #expect(stringArgument(args, "missing") == nil)
        #expect(stringArgument(nil, "s") == nil)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func `stringArgument rejects non-finite doubles`(_ value: Double) {
        #expect(stringArgument(["value": .double(value)], "value") == nil)
    }

    @Test
    func `intArgument truncates doubles and parses numeric strings`() {
        let args: [String: Value] = ["i": .int(7), "d": .double(3.9), "s": .string("42"), "bad": .string("nope")]
        #expect(intArgument(args, "i") == 7)
        #expect(intArgument(args, "d") == 3)
        #expect(intArgument(args, "s") == 42)
        #expect(intArgument(args, "bad") == nil)
        #expect(intArgument(args, "missing") == nil)
    }

    @Test
    func `intArgument rejects numbers no Int can hold, rather than trapping`() {
        // The SDK's decoder tries Int first and falls back to Double, so any JSON number
        // outside Int's range arrives as a `.double`. `Int(_: Double)` traps on each of
        // these, killing the server process on a single tool call.
        let args: [String: Value] = [
            "huge": .double(1e20),
            "tiny": .double(-1e20),
            "notANumber": .double(.nan),
            "infinite": .double(.infinity),
            "hugeString": .string("99999999999999999999")
        ]
        for key in args.keys {
            #expect(intArgument(args, key) == nil, "\(key) should not coerce to an Int")
        }
    }

    @Test
    func `intArgument truncates a fractional numeric string as it does a double`() {
        #expect(intArgument(["s": .string("3.9")], "s") == 3)
        #expect(intArgument(["s": .string("-3.9")], "s") == -3)
        #expect(intArgument(["s": .string("nope")], "s") == nil)
    }

    @Test
    func `optionalString trims and nils empties`() {
        let args: [String: Value] = ["x": .string("  hello  "), "blank": .string("   ")]
        #expect(optionalString(args, "x") == "hello")
        #expect(optionalString(args, "blank") == nil)
        #expect(optionalString(args, "missing") == nil)
    }
}

@Suite("Tool schema bridge")
struct ToolSchemaTests {
    @Test
    func `mcpValue maps each JSON type, checking Bool before Int`() {
        #expect(mcpValue(true) == .bool(true))
        #expect(mcpValue(5) == .int(5))
        #expect(mcpValue(2.5) == .double(2.5))
        #expect(mcpValue("x") == .string("x"))
        #expect(mcpValue([1, "a"]) == .array([.int(1), .string("a")]))
        #expect(mcpValue(["k": 1]) == .object(["k": .int(1)]))
        // An already-built Value passes through unchanged.
        #expect(mcpValue(Value.string("y")) == .string("y"))
    }

    @Test
    func `mcpValue preserves Foundation and fixed-width numbers`() {
        #expect(mcpValue(NSNumber(value: true)) == .bool(true))
        #expect(mcpValue(NSNumber(value: 1)) == .int(1))
        #expect(mcpValue(Int64.min) == .int(Int.min))
        #expect(mcpValue(Int64.max) == .int(Int.max))
        #expect(mcpValue(UInt(42)) == .int(42))
        #expect(mcpValue(Float(1.25)) == .double(1.25))
        #expect(mcpValue(UInt64.max) == .double(Double(UInt64.max)))
    }

    @Test
    func `mcpTool reads name, description, schema and annotations`() throws {
        let descriptor: [String: Any] = [
            "name": "list_things",
            "description": "Lists things.",
            "inputSchema": ["type": "object", "properties": ["page": ["type": "integer"]]],
            "annotations": ["title": "List things", "readOnlyHint": true, "destructiveHint": false]
        ]
        let tool = try #require(mcpTool(from: descriptor))
        #expect(tool.name == "list_things")
        #expect(tool.description == "Lists things.")
        #expect(tool.annotations.title == "List things")
        #expect(tool.annotations.readOnlyHint == true)
        #expect(tool.annotations.destructiveHint == false)
        #expect(tool.inputSchema == .object([
            "type": .string("object"),
            "properties": .object(["page": .object(["type": .string("integer")])])
        ]))
    }

    @Test
    func `mcpTool tolerates a partial descriptor`() throws {
        let tool = try #require(mcpTool(from: ["name": "bare"]))
        #expect(tool.name == "bare")
        #expect(tool.description == "")
        #expect(tool.inputSchema == .object([:]))
    }

    @Test
    func `mcpTools converts a whole catalog`() {
        let tools = mcpTools(from: [["name": "a"], ["name": "b"]])
        #expect(tools.map(\.name) == ["a", "b"])
    }

    @Test
    func `mcpTools omits descriptors without a usable name`() {
        let descriptors: [[String: Any]] = [
            [:],
            ["name": " \n\t "],
            ["name": 42],
            ["name": "  valid_tool  "]
        ]

        #expect(descriptors.dropLast().allSatisfy { mcpTool(from: $0) == nil })
        #expect(mcpTools(from: descriptors).map(\.name) == ["valid_tool"])
    }

    @Test
    func `mcpTool rejects a non-object inputSchema`() {
        #expect(mcpTool(from: ["name": "bad", "inputSchema": "not-an-object"]) == nil)
        #expect(mcpTool(from: ["name": "bad", "inputSchema": ["array", "values"]]) == nil)
        #expect(mcpTool(from: ["name": "bad", "inputSchema": 42]) == nil)
    }

    @Test
    func `mcpAnnotations maps idempotentHint and preserves unknown keys in meta`() throws {
        let descriptor: [String: Any] = [
            "name": "annotated",
            "annotations": [
                "title": "Annotated",
                "idempotentHint": true,
                "customHint": "keep-me"
            ]
        ]
        let tool = try #require(mcpTool(from: descriptor))
        #expect(tool.annotations.idempotentHint == true)
        #expect(tool._meta?["customHint"] == .string("keep-me"))
        #expect(tool._meta?["title"] == nil)
    }
}

@Suite("Result builders")
struct ResultTests {
    private func text(of result: CallTool.Result) -> String? {
        guard case let .text(text, _, _) = result.content.first else { return nil }

        return text
    }

    @Test
    func `textResult carries the text and optional error flag`() {
        #expect(text(of: textResult("ok")) == "ok")
        #expect(textResult("ok").isError == nil)
        #expect(errorResult("bad").isError == true)
        #expect(text(of: errorResult("bad")) == "bad")
    }

    @Test
    func `textResult rejects NUL bytes in tool output`() {
        let result = textResult("ok\0bad")
        #expect(result.isError == true)
        #expect(text(of: result)?.contains("NUL") == true)
    }

    @Test
    func `textResult utf8 Data rejects invalid sequences`() {
        let invalid = Data([0xFF, 0xFE, 0xFD])
        let result = textResult(utf8: invalid)
        #expect(result.isError == true)
        #expect(text(of: result)?.contains("UTF-8") == true)
    }

    @Test
    func `missingArgument names the argument and is an error`() {
        let result = missingArgument("pad")
        #expect(text(of: result)?.contains("pad") == true)
        #expect(result.isError == true)
    }

    @Test
    func `jsonResult reports values JSON can't express instead of aborting`() throws {
        // JSONSerialization raises an Objective-C NSException - uncatchable from Swift -
        // for each of these, so the documented error path has to be reached by checking
        // the object first.
        #expect(jsonResult(["average": Double.nan]).isError == true)
        #expect(jsonResult(["ratio": Double.infinity]).isError == true)
        #expect(jsonResult(["at": Date()]).isError == true)
        #expect(try jsonResult(["where": #require(URL(string: "https://example.com"))]).isError == true)
    }

    @Test
    func `jsonResult encodes sorted, decodable JSON`() throws {
        let result = jsonResult(["b": 2, "a": 1])
        let json = try #require(text(of: result))
        // Keys are sorted, so "a" precedes "b" in the serialized form.
        #expect(try #require(json.range(of: "\"a\"")?.lowerBound) < json.range(of: "\"b\"")!.lowerBound)
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Int]
        #expect(decoded == ["a": 1, "b": 2])
    }
}

@Suite("Stdio bootstrap")
struct StdioBootstrapTests {
    @Test
    func `wantsStdioMCP detects the flag past the executable path`() {
        #expect(MCPServer.wantsStdioMCP(["/path/to/app", "--mcp"]))
        #expect(MCPServer.wantsStdioMCP(["/path/to/app", "--other", "--mcp"]))
        #expect(!MCPServer.wantsStdioMCP(["/path/to/app"]))
        #expect(!MCPServer.wantsStdioMCP(["/path/to/app", "--other"]))
        // The flag in argv[0] (the executable path itself) doesn't count.
        #expect(!MCPServer.wantsStdioMCP(["--mcp"]))
    }

    @Test
    func `stdioModeFlag is the conventional --mcp`() {
        #expect(MCPServer.stdioModeFlag == "--mcp")
    }

    @Test
    func `a thrown server operation exits its process with failure`() throws {
        let fixture = Bundle(for: TestBundleMarker.self).bundleURL
            .deletingLastPathComponent()
            .appending(path: "MCPKitStdioFailureFixture")
        #expect(FileManager.default.isExecutableFile(atPath: fixture.path))

        let standardError = Pipe()
        let process = Process()
        process.executableURL = fixture
        process.standardError = standardError
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()

        let diagnostic = String(
            decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        #expect(process.terminationReason == .exit)
        #expect(process.terminationStatus == EXIT_FAILURE)
        #expect(diagnostic.contains("Fixture MCP server failed to start"))
    }
}

private final class TestBundleMarker: NSObject {}

/// A minimal provider that only implements the two required methods, so the optional
/// prompt/resource defaults are exercised.
private struct ToolsOnlyProvider: MCPToolProvider {
    func tools() async -> [Tool] {
        [Tool(name: "ping", description: "Ping.", inputSchema: .object([:]))]
    }

    func callTool(_ name: String, arguments _: [String: Value]?) async -> CallTool.Result {
        name == "ping" ? textResult("pong") : errorResult("Unknown tool: \(name)")
    }
}

private struct ThrowingToolProvider: MCPToolProvider {
    func tools() async -> [Tool] {
        [Tool(name: "fail", description: "Fails.", inputSchema: .object([:]))]
    }

    func callTool(_ name: String, arguments _: [String: Value]?) async throws -> CallTool.Result {
        throw MCPError.invalidParams("Provider rejected \(name)")
    }
}

@Suite("MCPToolProvider defaults")
struct ProviderDefaultTests {
    private let provider = ToolsOnlyProvider()

    @Test
    func `tools and callTool work as implemented`() async {
        #expect(await provider.tools().map(\.name) == ["ping"])
        let pong = await provider.callTool("ping", arguments: nil)
        guard case let .text(text, _, _) = pong.content.first else { Issue.record("no text"); return }

        #expect(text == "pong")
    }

    @Test
    func `prompts and resources default to empty`() async {
        #expect(await provider.prompts().isEmpty)
        #expect(await provider.resources().isEmpty)
        #expect(await provider.resourceTemplates().isEmpty)
    }

    @Test
    func `getPrompt defaults to throwing unknownPrompt`() async {
        await #expect(throws: PromptError.unknownPrompt("x")) {
            try await provider.getPrompt("x", arguments: nil)
        }
    }

    @Test
    func `readResource defaults to throwing unknownResource`() async {
        await #expect(throws: ResourceError.unknownResource("app://nope")) {
            try await provider.readResource("app://nope")
        }
    }

    @Test
    func `tool errors propagate through the server handler`() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        let client = Client(name: "TestClient", version: "1.0")
        let server = MCPServer(name: "TestServer", version: "1.0", provider: ThrowingToolProvider())

        try await server.start(transport: serverTransport)
        _ = try await client.connect(transport: clientTransport)

        let context: RequestContext<CallTool.Result> = try await client.callTool(name: "fail", arguments: nil)
        await #expect(throws: (any Error).self) {
            try await context.value
        }

        await client.disconnect()
    }

    @Test
    func `tools-only servers do not register unadvertised prompt handlers`() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        let client = Client(name: "TestClient", version: "1.0")
        let server = MCPServer(
            name: "TestServer",
            version: "1.0",
            capabilities: .init(tools: .init(listChanged: false)),
            provider: ToolsOnlyProvider()
        )

        try await server.start(transport: serverTransport)
        _ = try await client.connect(transport: clientTransport)

        let tools = try await client.listTools()
        #expect(tools.tools.map(\.name) == ["ping"])

        let request = ListPrompts.request(.init())
        let context: RequestContext<ListPrompts.Result> = try await client.send(request)
        await #expect(throws: (any Error).self) {
            try await context.value
        }

        await client.disconnect()
    }
}
