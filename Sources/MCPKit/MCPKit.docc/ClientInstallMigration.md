# Migrating client install instructions to MCPClientInstall

Keep desktop-client configuration out of MCPKit.

## Why a separate package

MCPKit serves tools; it does not own where Claude Desktop, Cursor, or other clients store
config files. Duplicate catalogues drift. Use
[MCPClientInstall](https://github.com/adamtheturtle/MCPClientInstall) and its
`MCPDesktopClient` catalogue for paths, formats, snippets, and safe file edits.

## Migration checklist

1. Remove any hardcoded client config paths or JSON templates from the host app.
2. Depend on `MCPClientInstall` and import its product where you show install UI.
3. Generate snippets with the catalogue API rather than string-concatenating JSON.
4. Link readers to MCPClientInstall documentation from any in-app "Connect a client" help.
5. Keep MCPKit focused on ``MCPToolProvider``, ``MCPServer``, and logging.

## Cross-links

- Package: https://github.com/adamtheturtle/MCPClientInstall
- MCPKit overview: <doc:MCPKit>
