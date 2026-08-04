import MCPKit

private struct FixtureFailure: Error {}

MCPServer.runOperationUntilExit(name: "Fixture") {
    throw FixtureFailure()
}
