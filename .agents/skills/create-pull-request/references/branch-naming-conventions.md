# Branch Types and Naming

## Enforce

- `main` is the trunk. Work reaches it through a pull request.
- Every branch type targets `main`. A leftover `develop` does not change the base.
- Work PRs squash-merge onto `main`.

## Branch Types

- `feature/<scope>-<short-description>`
  - Example: `feature/auth-signin-form`
- `fix/<scope>-<issue-or-bug>`
  - Example: `fix/build-vercel-edge-runtime`
- `chore/<tool>-<action>`
  - Example: `chore/eslint-upgrade`
- `refactor/<scope>-<what>`
  - Example: `refactor/ui-theme-provider`
- `docs/<scope>`
  - Example: `docs/readme-setup`
- `release/<version>`
  - Example: `release/1.2.0`
- `hotfix/<scope>`
  - Example: `hotfix/critical-auth-redirect`

## Conventions

- `kebab-case`; no spaces or uppercase.
- `<short-description>` is ≤5 words.
- Prefer specific scopes: `auth`, `ui`, `api`, `build`, `db`, `i18n`.

## Agent Behavior

- If the name is ambiguous, pick the closest valid type and keep the scope specific.
