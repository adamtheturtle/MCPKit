# ``MCPKit``

Scaffolding for exposing Swift app features as a Model Context Protocol server.

## Overview

`MCPKit` adds a small application layer around the official MCP Swift SDK. Implement
``MCPToolProvider`` with your tool catalog and dispatch, then serve it with ``MCPServer``
over stdio or another transport.

The package also includes helpers for JSON-backed tool descriptors, loose argument
coercion, result builders, prompt messages, JSONL activity logging, and client
configuration snippets.

## Topics

### Server

- ``MCPToolProvider``
- ``MCPServer``

### Tool descriptors

- ``mcpTools(from:)``
- ``mcpTool(from:)``
- ``mcpValue(_:)``

### Arguments and results

- ``stringArgument(_:_:)``
- ``intArgument(_:_:)``
- ``optionalString(_:_:)``
- ``textResult(_:)``
- ``errorResult(_:)``
- ``jsonResult(_:)``
- ``missingArgument(_:)``

### Prompts and clients

- ``PromptError``
- ``MCPClient``
- ``JSONLLog``
