# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 1.0.x | :white_check_mark: |
| < 1.0 | :x: |

## Reporting a Vulnerability

This project is a single MQL5 Expert Advisor file with no network communication, external API calls, or web server components. The primary security considerations relevant to this project are:

- **Local file handling**: the EA reads and writes a local cushion file (`CushionFileName`) using the standard MQL5 `FileOpen`/`FileWrite`/`FileRead` functions within the MetaTrader 5 sandboxed file system (`MQL5/Files` or the Common Files folder).
- **No credentials or secrets**: the EA does not request, store, or transmit broker credentials, API keys, or any external secrets.
- **No external network access**: the EA does not perform any HTTP requests, WebRequest calls, or DLL imports.

If you discover a security issue related to this code (for example, a way the cushion file parsing could be exploited, or unsafe handling of file input), please report it by:

1. Opening a [GitHub Issue](../../issues) labeled `security`, **without** including any real account numbers, balances, broker server names, or other sensitive personal/financial information.
2. Describing the issue, the affected function(s) in `SmartCushionEA.mq5`, and steps to reproduce it if applicable.

We will review reported issues as soon as possible and aim to provide an initial response within a reasonable timeframe given this is a community-maintained open-source project.

## Out of Scope

The following are explicitly **out of scope** for this security policy, as they are outside the control of this codebase:

- Vulnerabilities in the MetaTrader 5 platform itself or the MQL5 runtime (report these to MetaQuotes Software Corp.).
- Broker-side execution issues, requotes, slippage, or platform outages.
- Financial losses resulting from trading activity, market conditions, or misconfiguration of input parameters — see [DISCLAIMER.md](DISCLAIMER.md).

## Responsible Disclosure

We ask that you give the project maintainers a reasonable opportunity to address any reported issue before any public disclosure beyond the initial issue report.
