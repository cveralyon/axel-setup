# AXEL Multi-Runtime Roadmap

## Intent

AXEL should remain Claude Code-first because the current package is built around Claude Code hooks, slash commands, agents, skills, plugins, and `~/.claude` conventions. The next architecture step is to make those workflows portable to Codex and other agent runtimes through explicit adapters instead of diluting the Claude Code install path.

Default install target:

```bash
npx axel-setup
```

Equivalent explicit target:

```bash
npx axel-setup --target claude
```

Experimental non-default targets:

```bash
npx axel-setup --target codex
npx axel-setup --target generic --output ./axel-runtime
```

## Target Model

AXEL should separate reusable workflow intent from runtime-specific wiring.

| Layer | Purpose | Claude Code default | Codex target | Generic target |
| --- | --- | --- | --- | --- |
| Workflow content | prompts, review checklists, agent roles, model-routing policy | installed as commands, agents, and skills | installed as Codex instructions/skills where supported | exported as markdown/tooling bundles |
| Lifecycle automation | hooks, session summaries, memory extraction, cost logs | Claude Code hooks in `~/.claude/settings.json` | Codex-compatible scripts and AGENTS.md guidance | manual or wrapper-driven scripts |
| Runtime manifest | what was installed, profile, skipped components, target | `~/.claude/axel-manifest.json` | `$CODEX_HOME` or repo-local manifest | caller-provided manifest path |
| Safety defaults | conservative permissions and no destructive overwrite | current additive installer behavior | additive repo/workspace behavior | additive export-only behavior |

## Implementation Plan

### Implemented First Slice

1. `--target claude|codex|generic` is supported by the CLI and bootstrap, defaulting to `claude`.
2. `axel-manifest.json` declares `targets`, `defaultTarget`, and target-scoped required paths.
3. `axel-setup doctor --target <target>` validates the selected runtime root.
4. `codex` installs portable AXEL instructions, skills, agents, commands, scripts, and a manifest into `$CODEX_HOME` or `~/.codex`.
5. `generic` exports the same portable bundle into `--output <dir>` without touching home-directory agent config.
6. CI smoke tests cover dry-run behavior, Codex temp installs, generic output installs, target-aware doctor checks, and Claude backward compatibility.

### Remaining Native Adapter Work

1. Move more runtime-specific file placement behind dedicated adapter modules when the shell script grows beyond the current small target split:
   - `claude`: current behavior, preserved as default.
   - `codex`: add native Codex command, skill, and instruction wiring as the runtime surface stabilizes.
   - `generic`: add optional archive generation and machine-readable component metadata.
2. Keep GSD and third-party ecosystems external: detect and integrate when present, never vendor a frozen copy.
3. Add upgrade and uninstall workflows per target using the installed manifest.

## Compatibility Rules

- `claude` remains the only fully supported target. Codex and generic are experimental portable-asset targets.
- `--target claude` must remain backward-compatible with existing installs.
- Runtime adapters must not share hidden side effects. If a component cannot be mapped cleanly to a target, mark it unsupported in the manifest and print a skip reason.
- Model routing must remain explicit: target adapters can translate policy wording, but must not silently inherit the most expensive session model.
- Personal defaults stay opt-in through profiles; team-safe and minimal targets must be suitable for public OSS users.

## Acceptance Criteria

- `npx axel-setup --target claude --dry-run` produces the same class of output as today's default install.
- `npx axel-setup --target codex --dry-run` prints all planned Codex writes without creating files.
- `npx axel-setup --target generic --output <dir>` exports a reviewable bundle and does not touch home-directory agent config.
- `npm run check` covers target parsing, manifest validation, doctor behavior, and temp-home smoke installs for every supported target.
- README documents Claude Code as the default and links each non-default target as experimental until native runtime wiring is complete.
