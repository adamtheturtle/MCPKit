//
//  MCPClientTests.swift
//  MCPKitTests
//
//  Verifies that the deprecated client catalogue still produces configuration snippets
//  which preserve arbitrary dynamic names and executable paths in their target grammar.
//

import Foundation
@testable import MCPKit
import Testing
import TOMLDecoder

private struct CodexServerConfiguration: Decodable, Equatable {
    let command: String
    let args: [String]
}

private struct CodexConfiguration: Decodable {
    let mcpServers: [String: CodexServerConfiguration]

    private enum CodingKeys: String, CodingKey {
        case mcpServers = "mcp_servers"
    }
}

@Suite("Client configuration snippets")
struct ClientConfigurationSnippetTests {
    @Test
    func `codex snippet escapes arbitrary TOML keys and strings`() throws {
        let serverName = "my.server [\"quoted\"]\nnext"
        let command = "/Applications/My \\ App/\"binary\"\nnext\t\u{7f}"
        let snippet = MCPClient.codex.configSnippet(command: command, serverName: serverName)

        let configuration = try TOMLDecoder().decode(CodexConfiguration.self, from: Data(snippet.utf8))
        #expect(configuration.mcpServers == [
            serverName: .init(command: command, args: ["--mcp"])
        ])
    }

    @Test
    func `claude Code snippet preserves hostile shell arguments`() throws {
        let serverName = "server name; $(printf injected) ' \" `printf injected`\n--flag"
        let command = "/Applications/My App/$HOME/'\"\\binary\nnext"
        let snippet = MCPClient.claudeCode.configSnippet(command: command, serverName: serverName)
        let script = """
        claude() {
          printf '%s\\000' "$@"
        }
        \(snippet)
        """
        let output = Pipe()
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", script]
        shell.standardOutput = output

        try shell.run()
        shell.waitUntilExit()

        #expect(shell.terminationStatus == 0)
        let arguments = output.fileHandleForReading.readDataToEndOfFile()
            .split(separator: 0)
            .map { String(decoding: $0, as: UTF8.self) }
        #expect(arguments == ["mcp", "add", serverName, "--", command, "--mcp"])
    }
}
