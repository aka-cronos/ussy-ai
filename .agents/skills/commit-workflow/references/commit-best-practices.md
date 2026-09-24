# Commit best practices

## Enforce

- Conventional Commits. One logical change per commit.
- Subjects ≤72 chars; imperative mood; lowercase.

## Types

- feat: new user-facing feature
- fix: bug fix
- chore: tooling/infra/maintenance (no production code change)
- docs: documentation only
- refactor: code change that neither fixes a bug nor adds a feature
- perf: performance improvement
- test: add or update tests
- build: build system or dependencies
- ci: CI configuration/files
- style: formatting/whitespace (no code meaning change)
- revert: revert a previous commit

## Format

- Subject: `type(scope): short summary`
  - Example: `feat(auth): add email/password sign-in flow`
- Body (when the why is not obvious from the diff): **bullets**
  - Blank line between subject and body.
  - Each item starts with `- `, even for a single point.
  - One bullet per idea; nested only when needed.
  - Each physical line ≤72 characters; wrap with indented continuation.
- Footer (optional):
  - Breaking changes: `BREAKING CHANGE: description`
  - Issue refs (`Ref: #123`, `Closes: #456`) — footer, not the subject.

## Examples

- `fix(build): ensure edge runtime uses Node 18-compatible polyfills`
- `refactor(ui): extract Button variants to separate file`
- `docs: add environment setup and scripts`
- `perf(api): cache product list with revalidate=60`
- `test(auth): add e2e tests for reset flow`
- Avoid (body as prose):

  ```
  chore(deps): bump tooling packages

  Updates lockfile and adjusts CI cache paths after the upgrade.
  ```

- Prefer:

  ```
  chore(deps): bump tooling packages

  - Refresh lockfile after dependency bumps.
  - Point CI cache paths at new package manager layout.
  ```

## Agent Behavior

- Leave the commit authored by the human: no `Co-Authored-By` trailer for an AI assistant.
