# Security policy

MCPKit helps host apps expose tools over the Model Context Protocol and write
append-only JSONL activity logs under caller-chosen directories.

## Reporting a vulnerability

Please report vulnerabilities privately through
[GitHub Security Advisories](https://github.com/adamtheturtle/MCPKit/security/advisories/new)
rather than opening a public issue.

Do not include production secrets, account tokens, or personal data in a report.
Revoke any credential that may have been exposed.

## Scope notes

- Prefer private directories for activity logs. `JSONLLog` creates files with mode `0600`.
- Treat tool arguments and prompt inputs as untrusted client data.
- Host apps remain responsible for authorization, filesystem paths, and network access
  behind their `MCPToolProvider` implementations.
