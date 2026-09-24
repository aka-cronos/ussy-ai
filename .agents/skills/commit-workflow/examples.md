# Commit Workflow Examples

## Example 1: Mixed concerns

Staged:

- `.agents/rules/commit-best-practices.md`
- `.cursor/settings.json`
- `docs/architecture.md`
- `docs/overview.md`

Grouping, in commit order:

1. tooling/config (`.agents/**`, `.cursor/**`) → `chore(rules): add commit rules and workspace settings`
2. docs (`docs/**`) → `docs: add architecture and overview documentation`

Commit each group in that order, leaving only that group's files staged for each `git commit`.

## Example 2: Single concern

Staged:

- `docs/architecture-decisions.md`
- `docs/overview.md`

Message — note the body is a bullet list, never prose:

```
docs: update architecture decisions and overview

- Clarify the rationale behind the current architecture.
- Align overview terminology with the decision records.
```

One group, one commit.
