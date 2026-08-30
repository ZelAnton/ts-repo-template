# AGENTS.md

## Project

- This repository contains `__ProjectName__`, a TypeScript project.
- The public API lives in `src/`, re-exported from `src/index.ts`.
- Tests live in `tests/` (`*.test.ts`, discovered by Vitest).
- Keep the repository focused; do not introduce CLI, UI, hosting, logging, or dependency injection infrastructure unless explicitly requested.

## Agent instruction files are local-only in generated repos

> **Scope:** this section is for a repository **created from a template**, not the
> template itself. In the template, `CLAUDE.md`, `AGENTS.md`, and `.claude/` stay
> **tracked and pushed** — that is how the guidance ships. If you are reading this
> in the template repo, leave them tracked and do nothing.

In a generated repo, `CLAUDE.md`, `AGENTS.md`, and `.claude/` are local guidance for whoever (human or agent) works in the clone — not project source. Keep them **git-ignored and untracked** so they stay on disk for tooling but never reach the remote; each developer keeps their own. This is a **by-hand step — the init script does not do it** — done **before the first push**:

```bash
# Append last so `.claude/` overrides the earlier `!.claude/...` ship lines.
printf '\n/CLAUDE.md\n/AGENTS.md\n.claude/\n' >> .gitignore
git rm -r --cached CLAUDE.md AGENTS.md .claude
git add .gitignore && git commit -m "Keep agent instructions local"   # commit the ignore rule *and* the removals together
```

`git rm --cached` keeps the files on disk; an ignore rule alone won't untrack already-committed files. `init` deletes `TEMPLATE.md` and `docs/AGENT-INIT-GUIDE.md`, so this section is the surviving copy of the recipe downstream — consult that guide while it exists for precedence details and the caveat that a repo created via GitHub's *Use this template* already carries these files in its initial commit's history (untracking drops them from the tip only).

## Runtime

- Use Node.js (24 or later). The floor is declared once, in `.nvmrc` and `package.json` (`engines.node`); do not change it unless explicitly asked.
- The TypeScript compiler version is pinned by the `typescript` devDependency range in `package.json`; npm drives everything (installs dependencies, runs build/lint/type/test via `package.json` scripts).
- The package is **ESM-only** (`"type": "module"`); the build is plain `tsc` emitting `dist/` with `.d.ts` declarations. Do not add a bundler unless explicitly requested.

## Dependencies

- Do not introduce new dependencies without explicit approval.
- Add runtime dependencies with `npm install <pkg>` (they land in `package.json` `dependencies`); add dev tools with `npm install -D <pkg>`. Never hand-edit version pins ad hoc.
- **Commit `package-lock.json`.** It is the resolved, reproducible dependency set — tracked, not ignored. (The template itself ships no lockfile because its placeholder name cannot be resolved; run `npm install` once after init and commit the result.)
- The supply-chain audit tool is `npm audit` (a CI job scans the resolved tree against the npm advisory database; high/critical advisories fail). Treat a new advisory like a build failure.

## Architecture

- Keep all functionality available as reusable library APIs.
- Keep implementation details (helpers, platform-specific code, internal types) internal to the library.
- Do not expose implementation types publicly unless explicitly requested.
- Prefer simple, direct code over new abstractions.
- Minimize public API surface area; public API changes must be intentional and documented.
- Do not add dependency injection unless there is a concrete need.

## Build, references, and repository structure

- Source lives under `src/` (flat layout), tests under `tests/`, helper scripts under `scripts/`.
- `package.json` is the single project manifest: metadata, dependencies, the `exports` map, and the build/test/lint scripts all live there. Tool config sits beside it (`tsconfig.json`, `biome.json`).
- The tsconfig is split: `tsconfig.json` (strict, `noEmit`, covers `src` + `tests` — the typecheck/editor view) and `tsconfig.build.json` (extends it; emits `src` only into `dist/`).
- Module resolution is `NodeNext`: relative imports carry the `.js` extension even from `.ts` files (`import { x } from "./y.js"`).
- Re-export the public surface from `src/index.ts` (it is the package's only `exports` entry); reach into submodules for internals only.

## Build And Test

- Use `npm run build` to validate compilation and produce `dist/` (warnings are errors — strict tsconfig).
- Use `npm test` (Vitest) to run tests after a successful build.
- Use `npm run typecheck` (`tsc --noEmit` over src + tests) as the type gate and `npm run lint` (`biome check .`) as the lint gate — both are CI-enforced.
- A successful test run must execute the discovered tests, not only collect them.

## Formatting

- `.editorconfig` is the source of truth for indentation and line endings of non-TypeScript files; Biome owns `.ts`/`.js`/`.json` formatting (config: `biome.json`). `.claude/` is excluded from Biome — local agent config, not project source.
- The formatter is `npm run format` (`biome format --write .`); CI runs `biome ci .` and the lint set must be clean.
- Preserve LF line endings, except Windows batch files (`.cmd`/`.bat`) which require CRLF.

## TypeScript Style

- **Type everything.** Public functions, parameters, and returns carry explicit annotations; the tsconfig enforces `strict`, `noUnusedLocals`/`noUnusedParameters`, `noUncheckedIndexedAccess`, and `exactOptionalPropertyTypes` — no implicit `any`, no unused symbols.
- Use `import type { ... }` for type-only imports (`verbatimModuleSyntax` is on).
- Prefer standard-library (Node built-ins, `node:` specifiers) solutions over new dependencies. Minimize public API surface.
- Use `camelCase` for functions/variables, `PascalCase` for types/classes. Biome enforces the relevant lint set.
- Treat warnings as errors. Prefer simple, direct code.

### Exception / error handling style

- Prefer multi-line, braced handlers over collapsed one-liners. Re-throw anything you did not expect; never swallow errors wholesale.
- An empty/ignored `catch` branch must carry a comment explaining **what** is being swallowed and **why** ignoring is correct here. `// ignored` alone is not enough.

  ```typescript
  let config: Config;
  try {
    config = loadConfig(path);
  } catch (err) {
    if (!(err instanceof ConfigNotFoundError)) throw err;
    // No config on disk is expected on first run; fall back to defaults.
    config = defaultConfig();
  }
  ```

## Documentation

- All documentation and code comments must be written in English.
- Functional changes must include corresponding README updates when behavior, requirements, usage, or public API changes.
- Do not leave changed behavior undocumented.

## Changelog

- `CHANGELOG.md` is the single source of truth for release notes.
- The release workflow reads `## [Unreleased]` automatically to populate the GitHub Release body.
- **Every user-visible change must be accompanied by a `CHANGELOG.md` update in the same change set.** Non-negotiable for new/modified public API, behavioural changes, bug fixes, deprecations, removals. Pure internal refactors are the only exemption.
- Add a manual bullet under `## [Unreleased]` in the appropriate subsection (`### Added` / `### Changed` / `### Fixed` / `### Removed` / `### Deprecated`). Write it for a consumer, not the implementer. Replace the placeholder `-`.
- Do not modify versioned sections (`## [1.0.0]`, etc.) — those are managed by the release workflow.

### Auto-fill fallback

- If `## [Unreleased]` has no real bullets at release time, the workflow auto-generates entries from commits since the previous tag using `git-cliff` (config: `cliff.toml`). Manual entries always win.
- The first word of the commit subject decides the bucket (case-insensitive): `Add`/`Feat` → Added; `Fix`/`Bug` → Fixed; `Remove`/`Delete`/`Drop` → Removed; `Refactor`/`Update`/`Change`/`Rename`/`Perf`/`CI`/`Cleanup` → Changed; `Doc`/`Chore`/`Test`/`Style` and `Release v...`/merges → skipped; anything else → Changed (fallback).

## Release

- The release workflow (`.github/workflows/release.yml`) publishes to npm and attaches the built tarball plus a `SHA256SUMS` manifest to the GitHub Release.
- Publishing requires the `NPM_TOKEN` repository secret (or switch to npm Trusted Publishing / OIDC — see the publish step's comment).
- The version is single-source in `package.json` (`version`). The workflow computes the next version from the latest `v*` tag (or seeds the first release from the manifest), writes it back into `package.json` **before** packing so the tarball carries it, then commits and tags.
- **Step ordering invariant:** the npm publish is the only irreversible step, so it is the pivot. A secret preflight runs first; build/test/package and a *local* (unpushed) commit+tag run before the pivot; the publish runs next; the atomic commit+tag push to `main` and the idempotent GitHub Release run after. A failure before or at the publish leaves no remote/registry trace — re-run freely. **Once the tag is pushed to `main`, do not re-run the whole workflow** — finish the GitHub Release manually using the command the failing step prints. When editing `release.yml`, never move the publish after the tag push, and keep the post-pivot steps idempotent.

## Security Scanning

- **CodeQL** (`.github/workflows/codeql.yml`) runs GitHub's static analysis on `main` pushes/PRs and weekly. TypeScript is CodeQL-supported (`javascript-typescript`, `build-mode: none` — the extractor reads source directly).
- **npm audit** (a CI job) scans the resolved dependency tree against the npm advisory database and fails on a high/critical vulnerability.
- **Dependabot** keeps Actions and npm packages current.

## Comments

- Minimize comments. Write them only to explain why something exists, an architectural decision, or non-obvious platform/runtime behavior.
- Do not write comments describing what the code already says.

## Version control (Git)

This repository uses Git directly. Do not initialize or colocate another version-control system in the working tree.

### Starting work

- Before editing, run `git status --short --branch` and inspect the current branch and any existing changes.
- Keep refinements and follow-ups for the same task on the current feature branch.
- Do not mix unrelated work into the same branch or commit. If the working tree is clean, create a short kebab-case feature branch from `origin/main`. If unrelated work arrives while changes are still in progress, ask before stashing, switching branches, or creating another worktree.
- Preserve user-authored changes and do not amend or rewrite their commits without explicit agreement.

### Pushing to remote

The user signals "synchronise with remote" with a short trigger word (typically `pull` or `push`). On that signal, run the full sync:
1. `git fetch origin` — pull down remote movement before doing anything else.
2. Rebase the feature branch onto `origin/main` when the remote branch has advanced: `git rebase origin/main`.
3. Push the feature branch, never local `main`: use `git push --set-upstream origin HEAD` on the first push and `git push` afterwards.
4. Open or update a pull request into `main` (`gh pr create --base main --head <topic> --fill`). `main` advances only when the pull request merges; afterwards, fetch, update local `main` with a fast-forward-only pull, and delete the merged feature branch.

Never push without an explicit signal from the user. **Direct-push fallback:** where `main` is unprotected, `git push origin HEAD:main` remains available; once pull requests are required this is rejected for everyone except the release workflow's GitHub App, which sits in the ruleset's bypass list (`RELEASE_APP_ID` + `RELEASE_APP_PRIVATE_KEY`; see `release-token-bypass.md`).

### Undoing work

- **`git restore <path>`** discards selected unstaged changes; use `git restore --staged <path>` to unstage without deleting work.
- **`git revert <commit>`** reverses a published commit without rewriting shared history.
- **`git reflog`** locates earlier branch and `HEAD` positions when recovery is needed.
- Do not use `git reset --hard`, force-push, or rewrite published history without explicit approval.

Never hide a deliberate undo. Tell the user exactly which files or commits were reverted.

### Branches & safety

- Work is published through a **feature branch per pull request** (short kebab-case topic name), merged into `main` via pull request.
- Do not revert or amend changes the user authored without explicit agreement.
- Do not rewrite unrelated files when making a focused change.

## Command Conventions

- Commands and APIs should be idempotent where possible.
- Output should remain concise and script-friendly.
- Breaking changes must be explicit.
