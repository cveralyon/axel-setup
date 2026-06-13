# AXEL Runtime Instructions

AXEL is Claude Code-first by default, but this runtime bundle exposes the reusable parts of the workflow for agent runtimes that can read markdown instructions, skills, prompts, and helper scripts.

## Runtime Contract

- Treat this bundle as additive local configuration.
- Keep Claude Code-specific hooks, settings, plugins, launchd agents, and GSD installers out of non-Claude runtimes.
- Prefer explicit model routing for delegated work. Never let background agents silently inherit the most expensive session model.
- Use the files in `skills/` as operational instructions.
- Use the files in `agents/` as role definitions and review checklists.
- Use the files in `commands/` as prompt templates, even if the runtime does not support slash commands.
- Use `axel-manifest.json` as the install inventory for audits, upgrades, and doctor checks.

## Default Target

Claude Code remains the default and most complete AXEL target. Codex and generic targets intentionally install portable assets only until each runtime has dedicated adapters for hooks, settings, and native command wiring.
