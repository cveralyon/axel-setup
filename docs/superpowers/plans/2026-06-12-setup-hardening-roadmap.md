# AXEL Setup Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AXEL publishable and safer for third-party installation by hardening bootstrap behavior, tests, release automation, and public roadmap hygiene.

**Architecture:** Keep `bootstrap.sh` as the installer entrypoint, but move validation coverage into shell-based integration tests under `tests/`. Extend `bin/axel-setup.js` with subcommands that do not change installation semantics unless explicitly requested.

**Tech Stack:** Bash, Node.js built-ins, jq, GitHub Actions, npm.

---

### Task 1: Bootstrap Safety And Assets

**Files:**
- Modify: `bootstrap.sh`
- Test: `tests/bootstrap-behavior.sh`

- [ ] Write tests that prove `--dry-run` does not create `~/.claude`, recursive skill assets install, and skip flags prevent plugin, GSD, and launchd side effects.
- [ ] Run `bash tests/bootstrap-behavior.sh` and verify the new assertions fail.
- [ ] Update `bootstrap.sh` so dry-run wraps all filesystem writes, skill directories copy recursively, and `--skip-plugins`, `--skip-gsd`, `--no-launchd`, and `--profile` are parsed.
- [ ] Re-run `bash tests/bootstrap-behavior.sh` and verify it passes.

### Task 2: Profiles, Manifest, And Doctor

**Files:**
- Modify: `bootstrap.sh`
- Modify: `bin/axel-setup.js`
- Add: `axel-manifest.json`
- Test: `tests/cli-doctor.sh`

- [ ] Write tests that prove `axel-setup doctor --home <tmp>` detects installed files and missing files without mutating state.
- [ ] Run `bash tests/cli-doctor.sh` and verify it fails before implementation.
- [ ] Add manifest metadata for installable components and make bootstrap install the manifest into `~/.claude/axel-manifest.json`.
- [ ] Extend `bin/axel-setup.js` with `doctor`, `--help`, and bootstrap passthrough behavior.
- [ ] Re-run `bash tests/cli-doctor.sh` and verify it passes.

### Task 3: CI, Release, And Docs

**Files:**
- Modify: `scripts/ci/check.sh`
- Modify: `.github/workflows/ci.yml`
- Add: `.github/workflows/release.yml`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] Add checks for shfmt and shellcheck when available, without making local machines fail if the tools are absent.
- [ ] Add GitHub Actions installation for shellcheck and shfmt.
- [ ] Add npm provenance release workflow triggered by `v*` tags.
- [ ] Update README to make `npx axel-setup` the primary path after npm publish and document profiles and skip flags.
- [ ] Run `npm run check` and `npm run publish:dry-run`.

### Task 4: GitHub Roadmap Hygiene

**Files:**
- No repo file changes required.

- [ ] Create labels for roadmap phases and feature classes.
- [ ] Create milestone `v0.2.0 Setup Hardening`.
- [ ] Open public issues for release automation, installer one-liner, OSS core separation, harness tests, upgrade workflow, and metrics.
- [ ] Push branch and open PR.
