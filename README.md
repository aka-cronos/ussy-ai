# UssyAi

A macOS menu bar app that shows the subscription quotas of **Claude**, **Codex** and **Cursor** at a glance: how much you have used, how much is left and when each one resets.

> **Status:** in development. The MVP is specified in [#11](https://github.com/aka-cronos/ussy-ai/issues/11). For now, the app shows the Claude card with sample data.

## What it does

- A fixed menu bar icon opens a panel with one card per provider.
- Each quota is shown separately (e.g. "5 horas" and "Semanal"), with its own bar, its reset in local time and the time of the last reading. Quotas are never combined into a single percentage.
- A switch between used quota and remaining quota.
- If a provider fails, its card explains why (no session, expired session, offline, incompatible response…) and the others keep working. Missing data is never shown as zero.

The app's interface is in Spanish.

## Privacy

- Reuses, **read-only**, the sessions that already exist in Claude Code, Codex CLI and Cursor. It never asks for passwords, signs in, refreshes tokens or writes credentials.
- Only connects to `api.anthropic.com`, `chatgpt.com` and `api2.cursor.sh`. No telemetry and no server of its own.
- Quotas live only in memory; nothing is written to disk.

## Disclaimer

The endpoints the app uses to read quotas are **internal and undocumented** by the providers. They may change or stop working without notice. UssyAi is not affiliated with Anthropic, OpenAI or Anysphere.

## Requirements (planned)

- macOS 27, Apple Silicon.
- Full Xcode to build.
- A signed-in session in Claude Code, Codex CLI (ChatGPT mode) and/or Cursor.

## Build and test

```sh
xcodebuild test -scheme UssyAi -destination 'platform=macOS,arch=arm64'
xcodebuild build -scheme UssyAi -destination 'platform=macOS,arch=arm64' -derivedDataPath build
open build/Build/Products/Debug/UssyAi.app
```

## Repository layout

| Path | Contents |
|---|---|
| `UssyAi/` | App: menu bar icon, panel and SwiftUI presentation. |
| `UssyCore/` | Usage core: panel state, provider adapters and injectable dependencies. |
| `UssyCoreTests/` | Tests through the usage core, with fake dependencies. |
| `CONTEXT.md` | Domain vocabulary (used quota, reset, last valid reading…). |
| `docs/agents/` | Agent conventions: issues, triage labels, domain docs. |
| `prototypes/` | Throwaway panel prototypes (HTML, fictional data). |

Design decisions live in the [issues](https://github.com/aka-cronos/ussy-ai/issues?q=is%3Aissue) of map [#1](https://github.com/aka-cronos/ussy-ai/issues/1).

## License

[MIT](LICENSE).
