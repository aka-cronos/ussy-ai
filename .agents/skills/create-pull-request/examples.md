# PR Workflow Examples

## Example 1: Transplanting commits off `main`

**State:** on `main`, two commits ahead of `origin/main` — "feat(auth): add login form" and
"feat(auth): add validation".

**Run:**

1. Show both commits and ask for type and scope. User: "feature, authentication".
2. Propose `feature/auth-login-form` → confirm → `git checkout -b feature/auth-login-form`.
3. Ask: "Reset `main` to `origin/main`? This discards those commits from local `main`.
   (yes/no)" → confirm → `git checkout main && git reset --hard origin/main`.
4. `git checkout feature/auth-login-form && git push -u origin feature/auth-login-form`.
5. Base is `main`.
6. Create with this body file:

   ```markdown
   Adds the login form as the entry point for the auth flow.

   ## What's included

   - Login form with client-side validation (builds on #12)

   ## Manual checklist

   - [ ] Invalid credentials show the inline error, not a redirect
   - [ ] Successful login lands on the dashboard
   ```

   No `## Deviations from plan` — there was no spec to deviate from. No attribution footer.

## Example 2: Branch name off-convention

**State:** on `my-feature-branch` with commits ready.

**Run:**

1. Validation fails — no recognized type prefix.
2. Tell the user: "`my-feature-branch` doesn't match the conventions; it should look like
   `feature/<scope>-<description>`."
3. Ask: "Rename this branch or create a new one? (rename/new)"
4. Rename → `git branch -m feature/<scope>-<description>`. New → run the Example 1 transplant.
5. Continue from Step 4.
