# Swift Testing migration plan

MCPKit's unit tests already use [Swift Testing](https://developer.apple.com/xcode/swift-testing/)
(`import Testing`, `@Suite`, `@Test`) rather than XCTest.

## Current state

- `Tests/MCPKitTests` is a Swift Testing suite.
- Async server and transport tests use `await` with `#expect` / `#require`.
- CI runs `swift test`, which discovers Swift Testing cases.

## Remaining work (optional)

1. Prefer parameterized `@Test(arguments:)` wherever a table of inputs replaces
   copy-pasted cases (already used for non-finite doubles).
2. Keep process-level stdio fixtures as separate executables; do not force them into
   XCTest-style `XCTestCase` subclasses.
3. When adding new MCPServer integration tests, favor in-memory transports and
   Swift Testing suites over XCTest expectations.
4. Do not reintroduce `XCTest` imports unless a dependency forces it.

No further framework migration is required for day-to-day contributions.
