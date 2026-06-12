# Contributing to AXEL Setup

Thanks for helping improve AXEL Setup. This project packages reusable Claude Code workflows for engineering teams, with a focus on safe automation, repeatable setup, and practical agent operations.

## Project Scope

Good contributions usually improve one of these areas:

- Claude Code bootstrap reliability.
- Hooks, agents, commands, skills, or templates that are useful beyond one private team.
- Safety guardrails for agentic coding workflows.
- Documentation that helps a new user install, audit, or adapt AXEL.
- Tests and validation that make releases easier to trust.

Please avoid adding private company workflow details, credentials, customer data, or project specific rules that would not make sense for other teams.

## Local Setup

Clone the repo and run the smoke checks:

```bash
git clone https://github.com/cveralyon/axel-setup.git
cd axel-setup
npm run check
```

Preview the installer without changing your real Claude configuration:

```bash
npm run smoke
```

You can also run the bootstrap manually:

```bash
bash bootstrap.sh --dry-run --user-name "Your Name"
```

## Pull Request Guidelines

Before opening a PR:

- Keep changes focused on one logical improvement.
- Update `README.md` when user facing behavior changes.
- Update `CHANGELOG.md` for meaningful additions, removals, fixes, or workflow changes.
- Run `npm run check`.
- Do not include secrets, local paths, or private customer context.

## Design Principles

- Additive installation: existing user configuration should be preserved.
- Explicit safety: risky automation should be visible and easy to audit.
- Portable defaults: examples should work for teams outside the original author environment.
- Small sharp tools: each hook, command, skill, or agent should have a clear job.

## Reporting Security Issues

If you find a security problem, avoid publishing exploit details in a public issue. Open a minimal issue asking for a private coordination channel, or contact the maintainer directly through GitHub.
