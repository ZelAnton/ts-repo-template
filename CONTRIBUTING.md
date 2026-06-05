# Contributing to __ProjectName__

Thanks for your interest in improving **__ProjectName__**.

## Prerequisites

- Node.js 24 (Krypton, LTS) or later — the floor is pinned in `.nvmrc`. npm ships
  with it; run `scripts/check-env.sh` (or `scripts/check-env.ps1`) to confirm.

## Build and test

```sh
npm install            # resolve dependencies (once per clone)
npm run build          # compile to dist/ (warnings are errors)
npm test               # run the tests (Vitest)
npm run typecheck      # type-check src + tests (strict)
npm run lint           # lint + format check (Biome)
```

`tsc` (strict), `biome check`, and `vitest` are the gates CI enforces, so run
them locally before opening a pull request.

## Conventions

- **Formatting and linting** are governed by [Biome](https://biomejs.dev/)
  (config in [`biome.json`](biome.json)). Run `npm run format` to apply
  formatting; don't reformat code you are not changing.
- **Dependencies** are declared in `package.json` and pinned in
  `package-lock.json` (commit the lockfile). Add them with `npm install <pkg>` /
  `npm install -D <pkg>`, not by hand.
- See [`AGENTS.md`](AGENTS.md) for the full, authoritative set of conventions.

## Changelog

Every user-visible change ships its [`CHANGELOG.md`](CHANGELOG.md) entry in the
same change set, under `## [Unreleased]`. Write the bullet for a consumer of the
library, not the implementer. Pure internal refactors are exempt.

## Pull requests

- Keep changes focused; unrelated cleanups belong in their own PR.
- Ensure CI (lint, type-check, and tests on Linux, Windows, macOS) passes.
- Fill in the pull-request checklist.
