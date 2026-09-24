# Contributing

Thanks for your interest in Uzzy. It is a small personal project, so please read this before you spend time on a change.

## Start with an issue

Open an [issue](https://github.com/aka-cronos/uzzy/issues/new/choose) before you open a pull request, and wait until it is agreed. Pull requests without an agreed issue may be closed. Design decisions live in the issues of map [#1](https://github.com/aka-cronos/uzzy/issues/1).

If a provider changed its API and a card now shows «Respuesta incompatible» or wrong data, use the **Provider API changed** template.

## Language

Write everything in English: issues, pull requests, commits, code, comments, tests and docs. The one exception is the app's user-facing copy, which stays in Spanish. Some older issues are in Spanish; they stay as they are.

## Build and test

You need macOS 27 on Apple Silicon and Xcode 27.

```sh
xcodebuild test -scheme Uzzy -destination 'platform=macOS,arch=arm64'
xcodebuild build -scheme Uzzy -destination 'platform=macOS,arch=arm64' -derivedDataPath build
open build/Build/Products/Debug/Uzzy.app
```

Tests go through the usage core with the fake dependencies in `UzzyCore/Fakes.swift`; they never touch real sessions or the network. To see a panel state without touching your accounts, use the debug scenarios described in the [README](README.md#debug-scenarios).

### Signing

By default the app is signed ad hoc ("Sign to Run Locally"), so it builds without an Apple Developer account. With ad hoc signing, macOS treats every rebuild as a different app, so the Keychain prompt to read Claude Code's session comes back after each build even if you chose «Always Allow».

To sign with your own team, create `Config/Local.xcconfig` (ignored by git):

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
```

Do not commit a team ID to `Uzzy.xcodeproj`.

## Data and privacy

Test fixtures and sample responses must be sanitized: no real tokens, emails, account IDs or provider responses, in code, issues or pull requests. See [Privacy](README.md#privacy) for what the app may read and where it may connect; a change that widens that needs to be agreed in an issue first.

## Domain language

Use the terms in [CONTEXT.md](CONTEXT.md) (subscription quota, reset, last valid reading, session, account…) in code, issues and pull requests.

## Commits and pull requests

- Never commit to `main`; every change reaches it through a pull request.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, imperative, lowercase, subject up to 72 characters. See `.agents/skills/commit-workflow/references/`.
- Keep one logical change per commit and link the issue in the pull request.

## Working with agents

The repository is developed with coding agents. [AGENTS.md](AGENTS.md) holds their instructions, and `.agents/skills/` the skills they use (linked from `.claude/skills/`). You don't need an agent to contribute, but the same rules apply to both.
