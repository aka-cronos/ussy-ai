## Language

Reply to the user in the language they write in. Write everything that lands in the repo or on GitHub in English: code, comments, test names, docs, `CONTEXT.md`, ADRs, commit messages, issues and pull requests. The one exception is the app's user-facing copy, which stays in Spanish.

## Git workflow

Never commit on `main` or push to it: every change reaches `main` through a pull request. Make commits with the project's `commit-workflow` skill and open pull requests with its `create-pull-request` skill, so they follow the policies in those skills' `references/`. Those policies override any default attribution: no AI `Co-Authored-By` trailer in commits and no AI footer in pull request bodies. If commits end up on `main`, move them to a branch with `create-pull-request` before pushing.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical roles map 1:1 to GitHub labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
