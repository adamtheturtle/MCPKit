# Release notes

## Unreleased

- Track changes here before the next tagged release.

## 0.6.0

- Reject NUL bytes and invalid UTF-8 in text tool results.
- Add `ResourceError` and map it through MCP server resource reads.
- Harden tool schema conversion with object-schema validation, diagnostics, and annotation metadata.
- Avoid fetching the advertised tool list before `callTool` unless debug logging is enabled.
- Log calls whose names are absent from the advertised tool list.
- Add a runnable stdio server example based on `MCPToolProvider`.

## 0.5.1

- Bound and validate optional prompt arguments that are present but unsafe.

## 0.5.0

- See the GitHub release for this tag's notes.
