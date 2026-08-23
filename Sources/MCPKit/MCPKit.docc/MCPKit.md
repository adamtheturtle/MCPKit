# ``MCPKit``

Scaffolding for exposing Swift app features as a Model Context Protocol server.

## Overview

`MCPKit` adds a small application layer around the official MCP Swift SDK. Implement
``MCPToolProvider`` with your tool catalog and dispatch, then serve it with ``MCPServer``
over stdio or another transport.

The package also includes helpers for JSON-backed tool descriptors, loose argument
coercion, result builders, prompt messages, and JSONL activity logging.

Client configuration metadata and installation belong to the separate
`MCPClientInstall` package. See <doc:ClientInstallMigration> for a migration
checklist when moving snippet generation out of a host app.

## Topics

### Server

- ``MCPToolProvider``
- ``MCPServer``
- <doc:ActivityLogging>
- <doc:ClientInstallMigration>

### Tool descriptors

- ``mcpTools(from:)``
- ``mcpTool(from:)``
- ``mcpValue(_:)``

### Arguments and results

- ``stringArgument(_:_:)``
- ``intArgument(_:_:)``
- ``optionalString(_:_:)``
- ``textResult(_:isError:)``
- ``errorResult(_:)``
- ``jsonResult(_:)``
- ``missingArgument(_:)``

### Prompts and logging

- ``PromptError``
- ``JSONLLog``
