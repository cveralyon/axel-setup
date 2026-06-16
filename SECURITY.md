# Security Policy

## Scope

AXEL Setup is a developer tooling installer. It writes files exclusively into `~/.claude` (hooks, agents, commands, skills, and settings). It does not run as a daemon, does not open network ports, and does not handle credentials or personal data at runtime.

Security issues in scope include:

- Arbitrary file writes outside `~/.claude` during install or uninstall.
- Path traversal or injection in `install.sh`, `bootstrap.sh`, or the Node CLI.
- Supply-chain risks in the curl pipe installer (e.g., compromised release tags or unsigned packages).
- Hook scripts that execute untrusted input without sanitisation.
- `settings.json` templates that silently grant `bypassPermissions` without user awareness.

Out of scope (not treated as vulnerabilities):

- Issues in Claude Code itself or its underlying model (report those to Anthropic).
- Theoretical risks that require the attacker to already have write access to `~/.claude`.
- Missing features or documentation gaps (use a regular GitHub issue).

## Reporting a Vulnerability

Please do **not** open a public GitHub issue for security vulnerabilities.

Use [GitHub private security advisories](https://github.com/cveralyon/axel-setup/security/advisories/new) to report the issue privately. Include:

- A description of the vulnerability and the affected component.
- Steps to reproduce or a proof-of-concept (a minimal script is fine).
- The version of `axel-setup` and Node.js you tested against.

If you prefer email, contact the maintainer directly: **Cristian Vera** at the address listed in `package.json` author URL (`https://github.com/cveralyon`). GitHub private advisories are preferred because they keep the disclosure timeline auditable.

## Response Commitment

This project has one maintainer. There is no SLA, but the goal is:

- Acknowledge receipt within 5 business days.
- Provide a fix or mitigation plan within 30 days for confirmed vulnerabilities.
- Credit reporters in the release notes unless they prefer to remain anonymous.

Fixes are published as patch releases on npm with a CHANGELOG entry under the `### Fixed` heading. Critical issues may warrant an out-of-band patch release before the next scheduled version.

## Supported Versions

Only the latest npm release is actively maintained. Older versions do not receive backported fixes.
