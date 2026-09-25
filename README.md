# Uzzy

A macOS menu bar app that shows the subscription quotas of **Claude**, **Codex** and **Cursor** at a glance: how much you have used, how much is left and when each one resets.

> **Status:** in development. The MVP is specified in [#11](https://github.com/aka-cronos/uzzy/issues/11). The app reads real quotas for Claude, Codex and Cursor from the sessions on this Mac.

## What it does

- A fixed menu bar icon opens a panel with one card per enabled provider.
- Each quota is shown separately (e.g. "5 horas" and "Semanal"), with its own bar, its reset in local time and the time of the last reading. Quotas are never combined into a single percentage.
- A Settings window (⌘, from the panel or Settings; ⌘W closes it, ⌘Q quits) to choose used or remaining quota and enable or disable each provider. These choices are remembered across launches; disabled providers are not queried.
- If a provider fails, its card explains why (no session, expired session, offline, incompatible response…) and the others keep working. Missing data is never shown as zero.

The app's interface is in Spanish.

## Privacy

- Reuses, **read-only**, the sessions that already exist in Claude Code, Codex CLI and Cursor. It never asks for passwords, signs in, refreshes tokens or writes credentials.
- Only connects to `api.anthropic.com`, `chatgpt.com` and `api2.cursor.sh`. No telemetry and no server of its own.
- Quotas live only in memory; nothing is written to disk.
- Display magnitude and provider visibility preferences are stored in local `UserDefaults`; they contain no quota, token, email or account identifier.

## Disclaimer

The endpoints the app uses to read quotas are **internal and undocumented** by the providers. They may change or stop working without notice, and each person is responsible for using them within their provider's terms.

Uzzy is an independent project, not affiliated with, endorsed by or sponsored by the makers of Claude, Codex, ChatGPT or Cursor. All product names and trademarks belong to their respective owners.

## Requirements

- macOS 27 on Apple Silicon.
- Xcode 27 to build. There are no prebuilt releases: you build Uzzy yourself.
- A signed-in session in Claude Code, Codex CLI (ChatGPT mode) and/or Cursor.

## Build and test

No Apple Developer account is needed: by default the app is signed ad hoc ("Sign to Run Locally"). To sign with your own team, see [Signing](CONTRIBUTING.md#signing).

```sh
xcodebuild test -scheme Uzzy -destination 'platform=macOS,arch=arm64'
xcodebuild build -scheme Uzzy -destination 'platform=macOS,arch=arm64' -derivedDataPath build
open build/Build/Products/Debug/Uzzy.app
```

### Install

To keep Uzzy running day to day, build it in Release and copy it to `/Applications`:

```sh
xcodebuild build -scheme Uzzy -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath build
cp -R build/Build/Products/Release/Uzzy.app /Applications/
open /Applications/Uzzy.app
```

To open it at login, add it under System Settings → General → Login Items.

Debug builds run as a separate app, «Uzzy Debug» (`com.akacronos.Uzzy.debug`), with an orange menu bar icon. They keep their own settings, so they can run next to the installed copy without touching it. The first time, the Debug build asks for Keychain access again.

### Debug scenarios

Debug builds add a bar on top of the panel to pick a scenario: the real panel then shows one of its states («Desactualizado», «Sin sesión», «Respuesta incompatible»…) with fictional data, without touching the accounts. The scenarios drive the usage core through the same fakes as the tests. To open the panel straight on one, pass its id (see `UzzyCore/Scenarios.swift`):

```sh
build/Build/Products/Debug/Uzzy.app/Contents/MacOS/Uzzy -scenario stale
```

Release builds leave the scenarios, the fakes and the sample responses out.

## Repository layout

| Path | Contents |
|---|---|
| `Uzzy/` | App: menu bar icon, panel and SwiftUI presentation. |
| `UzzyCore/` | Usage core: panel state, provider adapters and injectable dependencies. In Debug builds, also the fake dependencies, the sample responses and the debug scenarios. |
| `UzzyCoreTests/` | Tests through the usage core, with the fake dependencies. |
| `CONTEXT.md` | Domain vocabulary (used quota, reset, last valid reading…). |
| `Config/` | Shared build settings (signing). |
| `docs/agents/` | Agent conventions: issues, triage labels, domain docs. |
| `.agents/skills/` | Agent skills used to work on the repo, copied from their upstream repos (see `skills-lock.json`). |

Design decisions live in the [issues](https://github.com/aka-cronos/uzzy/issues?q=is%3Aissue) of map [#1](https://github.com/aka-cronos/uzzy/issues/1).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Acknowledgements

Endpoint research was informed by [OpenUsage](https://github.com/robinebers/openusage) (MIT) and [openai/codex](https://github.com/openai/codex) (Apache-2.0). No code was copied from either.

## License

[MIT](LICENSE). The agent skills under `.agents/skills/` are third-party MIT code; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
