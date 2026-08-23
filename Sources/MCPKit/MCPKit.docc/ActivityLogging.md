# Activity logging with JSONLLog

Record headless `--mcp` launches in a shared JSONL activity log.

## Overview

A GUI process and a headless MCP process do not share memory. Use ``JSONLLog`` in a
directory both can reach, and append from the `onLaunch` closure of
``MCPServer/runOverStdioUntilExit(name:version:capabilities:isEnabled:disabledMessage:onLaunch:provider:)``
(and from tool handlers if desired) so a settings pane can tail recent activity.

## Example

```swift
import Foundation
import MCPKit

struct ActivityEntry: Codable, Sendable {
    var timestamp: Date
    var event: String
}

let activityLog = JSONLLog<ActivityEntry>(
    directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "MyApp", directoryHint: .isDirectory),
    fileName: "mcp-activity.jsonl",
    maxEntries: 200
)

MCPServer.runOverStdioUntilExit(
    name: "MyApp",
    onLaunch: {
        activityLog.append(ActivityEntry(timestamp: .now, event: "mcp-launch"))
    },
    provider: MyProvider()
)
```

Pass an explicit `version:` when the binary has no `Info.plist`. See
``MCPServer/bundleShortVersion``.
