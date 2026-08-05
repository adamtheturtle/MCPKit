# MCPKit

Scaffolding for exposing Swift app features as a Model Context Protocol server, built on
the official MCP Swift SDK.

[Documentation](https://swiftpackageindex.com/adamtheturtle/MCPKit/documentation/mcpkit) |
[Swift Package Index](https://swiftpackageindex.com/adamtheturtle/MCPKit)

## Installation

```swift
.package(url: "https://github.com/adamtheturtle/MCPKit.git", from: "0.1.0")
```

Add the `MCPKit` product to your target dependencies.

## Product

- `MCPKit`: Provider protocols, server bootstrap, argument helpers, result builders, and
  activity logging for MCP integrations.

## Client configuration migration

Applications that show client setup instructions or edit client configuration should use
[`MCPClientInstall`](https://github.com/adamtheturtle/MCPClientInstall) and its
`MCPDesktopClient` catalogue. Keeping client paths, formats, snippets, and safe file
editing in that package prevents duplicate catalogues from drifting.

## Requirements

- Swift 6.1+
- macOS 13+, Mac Catalyst 16+, iOS 16+, watchOS 9+, tvOS 16+, or visionOS 1+

## License

MIT. See [LICENSE](LICENSE).
