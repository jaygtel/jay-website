# Deferred: PR build check + auto-merge (Issue #98)

**Status:** Deferred (no code added)  
**Reason:** Not working on this right now; keeping a placeholder for future work.

## What we intentionally did **not** do
- No workflow files added to `.github/workflows/`
- No repository settings changed
- No `package.json` scripts altered

## When we pick this back up
1. Add `.github/workflows/pr-build.yml` to build PRs (Node 20, `npm ci`, `npm run build:local` → fallback `npm run build`).
2. Target PRs into `ms/m03` and `main`.
3. Optionally run ESLint/Prettier jobs if configs exist.
4. Enable “Allow auto-merge” in repo settings and choose it per PR if desired.

*This note exists only to record that Issue #98 is deliberately deferred.*
