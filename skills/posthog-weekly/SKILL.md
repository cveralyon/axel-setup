---
name: posthog-weekly
description: Weekly PostHog analytical review. Pulls raw data from your PostHog project, identifies anomalies, regressions, and improvement opportunities, suggests new instrumentation and cohorts, then writes a condensed snapshot that other commands (sprint-status, eod-review, daily) can read for the next 14 days.
---

# PostHog Weekly Review

You are a senior product analytics consultant analyzing a PostHog workspace for **{{POSTHOG_PROJECT_CONTEXT}}**.

Your job is **NOT** to dump numbers. Your job is to **interpret** the data: find what is broken, what is regressing, what looks weird, what could be improved, and what is missing from the instrumentation. Every finding must be paired with a concrete recommended action.

Respond in **{{ASSISTANT_LANGUAGE}}**.

## When to use

- Once a week (typical cadence). The skill caches its output for 14 days, so other commands can read the analysis without re-querying PostHog.
- Whenever the user says "review my PostHog", "check the metrics", "what's going on in PostHog", "weekly product review".
- After a release, to look for regressions or new error spikes.
- Before a stakeholder review meeting.

## Pre-requisites

The PostHog MCP must be authenticated. Verify with `claude mcp list | grep posthog`. Expected output: `posthog: https://mcp.posthog.com/mcp (HTTP) - ✓ Connected`. If you only see `Needs authentication`, ask the user to authenticate via `/mcp` and stop — do not proceed without real data, and never invent metrics.

## Step 1 — Gather raw data (parallel calls)

Run all of these in **a single parallel batch** to minimize round-trips:

1. `mcp__posthog__organizations-get` — confirm the active org
2. `mcp__posthog__projects-get` — confirm the active project
3. `mcp__posthog__dashboards-get-all` (limit 50) — focus on `pinned: true`
4. `mcp__posthog__insights-list` (limit 100) — surface what's already saved
5. `mcp__posthog__event-definitions-list` (limit 200) — sorted by `last_seen_at` descending. This is **critical** — the `last_seen_at` field is how you detect events that stopped firing.
6. `mcp__posthog__feature-flag-get-all` (active=true) — what's currently rolled out
7. `mcp__posthog__experiment-get-all` — running experiments
8. `mcp__posthog__cohorts-list` — defined segments
9. `mcp__posthog__error-tracking-issues-list` (limit 50) — active errors

**Do not skip events with old `last_seen_at`.** Those are the most analytically interesting — they tell you which features are dead.

## Step 2 — Quantitative pass: pull comparison data

For the **5–10 most important product events** (identify them from event-definitions-list — events that look like core user actions, not framework noise like `$pageview` or `$autocapture`), run a trends query for the last 14 days, weekly interval, comparing current week to previous week:

Use `mcp__posthog__query-run` with a `TrendsQuery` shaped like:

```json
{
  "query": {
    "kind": "InsightVizNode",
    "source": {
      "kind": "TrendsQuery",
      "dateRange": { "date_from": "-14d" },
      "interval": "week",
      "compareFilter": { "compare": true },
      "series": [
        { "kind": "EventsNode", "event": "<event_name>", "math": "total", "custom_name": "<event_name>" }
      ]
    }
  }
}
```

Batch 5–10 of these in parallel. From the results, compute the week-over-week delta for each event. **Flag anything with > 30% drop or > 50% spike** — those are the candidates for the regression / anomaly section.

## Step 3 — Apply the analytical lens

Walk through the data and look specifically for these patterns. For each one, formulate a concrete finding paired with a recommended action.

### A) Dead or dying events

For each event in `event-definitions-list`:

- If `last_seen_at` is **> 7 days ago** for an event that looks like a core user action (not a framework event), this is a **red flag**. Either the feature was removed, the tracking broke, or no user touches it. Distinguish between these three with cross-referencing:
  - Is the feature mentioned in any pinned dashboard insight? → Check insights-list.
  - Is there a related `*_failed` or `*_error` event still firing? → That points to a bug.
  - Is the absence consistent across the entire project? → Likely deprecated.
- Group dead events by feature area in your output. Don't list 30 dead events one by one — say "the entire `feature_x_*` family hasn't fired in 18 days, last seen 2026-XX-XX, suggests feature deprecation or tracking break".

### B) Regressions in active events

From the Step 2 trends queries:

- Events with **> 30% week-over-week drop** are regression candidates. Cross-reference:
  - Is there a release annotation on the same date? → likely a release bug.
  - Is the drop concentrated in one breakdown (browser, device, plan)? → environment-specific.
  - Is it correlated with a spike in errors? → broken instrumentation or broken feature.
- Events with **> 50% spike** are also worth flagging. Could be: a new feature launched, a bot, a marketing campaign, or an instrumentation duplication bug. Investigate before celebrating.

### C) Funnel friction

For each pinned dashboard, identify funnels (look for insights with `FunnelsQuery` shape) and find:

- The step with the **largest absolute drop-off**.
- Cross-reference that step with `$rageclick`, `$dead_click`, `$exception`, and `$autocapture` events on the same page or component, if breakdown by URL is available.
- The hypothesis: "users drop here because X" — and a recommended action: "investigate the <component> on <page>, check for blocking errors or confusing UX".

### D) Error tracking debt

From `error-tracking-issues-list`:

- Count active issues. Anything > 20 is a backlog signal.
- Count issues **without an `assignee`** — that's the triage debt.
- Identify issues with `first_seen` in the last 7 days — those are **new this week** and most likely related to a recent release.
- Surface the top 5 by recency or frequency with a one-line action: "assign and triage MAI-XXXX before next deploy".

### E) Feature adoption gaps

For the core product features (identified from event family names like `feature_x_created`, `feature_x_completed`):

- Compute the **completion rate**: `feature_x_completed / feature_x_started`. If < 50%, that's a friction point worth flagging.
- Compute the **user concentration**: how many distinct users fired the event in the last 14 days. If a feature is used by 3 power users and nobody else, it's at risk of being abandoned.
- Compare adoption across the 3-5 main features and highlight the one with the lowest adoption — that's the candidate for either a UX redesign or deprecation.

### F) Quality of instrumentation

This is **the most important section for evolving the product analytics**. Look for gaps:

- **Auth events**: is there a `signup_completed`, `login_succeeded`, `logout`, `email_verified`? If not, the user cannot measure D1/D7/D30 retention or activation rate. **Recommend instrumenting at the SDK level** (frontend and backend).
- **Onboarding milestones**: is there a `first_<core_action>` event for first-time users? Without this you can't measure activation.
- **Billing events**: if the product is SaaS — `subscription_started`, `trial_expired`, `payment_failed`, `upgrade`, `downgrade`, `churn`. Without these the team is blind to revenue funnels.
- **Backend events**: do you only see frontend `$exception`? If yes, recommend the user push backend errors via the PostHog SDK (Python/Ruby/Node) with the same `distinct_id` as the frontend session. Without it, AI agent timeouts, scraper failures, and 5xx errors are invisible to analytics.
- **Performance regressions**: if the project has Web Vitals events (`LCP`, `INP`, `CLS`), check if any percentile is degrading week-over-week. These are leading indicators of UX problems.

For each gap, **propose the exact event name** and the **expected payload shape** (what properties should it carry). Make it actionable — the user should be able to copy the suggestion into a Jira/Linear ticket.

### G) Cohorts that should exist

If `cohorts-list` returned 0 or very few cohorts, this is an **opportunity**, not a bug. Suggest 4-6 cohorts that match the product:

- **Power users** — fired the core action ≥ N times in last 7 days
- **Churned users** — no events in last 21 days
- **Onboarding stuck** — signed up > 7 days ago but never completed the first core action
- **Trial converts** — once billing is instrumented
- **Heavy users of feature X** — to compare retention by feature usage
- **One per main product surface** — to enable per-feature retention curves

For each suggested cohort, provide the **exact behavioral filter** so the user (or you, in a follow-up) can create it via `mcp__posthog__cohorts-create`.

### H) Feature flags & experiments

If both are 0, the team is **leaving capability unused**. Mention it briefly — not as a finding, but as a "you're paying for this, here's how to get value":

- "0 feature flags active — consider gating new features behind a flag for safer rollouts and gradual exposure"
- "0 experiments — consider running an A/B on the lowest-converting funnel step you identified above"

Don't lecture. Just plant the seed.

## Step 4 — Generate the report

The output is a **markdown report**, written in `{{ASSISTANT_LANGUAGE}}`, with this exact structure:

```markdown
# 📊 PostHog Weekly Review — <YYYY-MM-DD>

**Project:** <project_name> (<project_url>)
**Window analyzed:** Last 14 days (current week vs previous)
**Generated by:** /posthog-weekly

## 🚨 Critical findings — act this week

[3-7 bullets. Each bullet is one finding + one recommended action. Format:
**[severity]** Finding sentence. → Action sentence.

severity = CRITICAL / HIGH / MEDIUM]

## 📉 Regressions & anomalies

[Events that dropped >30%, errors growing, funnel breaks, dead events.
Group by area. Don't dump a list of 30 dead events — synthesize.]

## ✅ Wins & positive trends

[Things working well. Growing usage, fixed errors, improved funnels, low
error rates. Keep this short — one or two genuine wins is better than five
weak ones. If there's nothing genuine to celebrate, write one line saying so.]

## 🎯 Improvement opportunities

[Funnel friction points + UX hypotheses + concrete next steps.
Each item: where the friction is, what the data says, what to try next.]

## 🔍 Instrumentation gaps & suggested new metrics

[What's missing that would be valuable to track. Be specific:
- Suggested event name (e.g. `signup_completed`)
- Expected payload (what properties to capture)
- Why it matters (what question it would answer)
]

## 💡 Suggested cohorts to create

[4-6 cohorts with their behavioral filter spec. Write them in a way that's
ready to be created via mcp__posthog__cohorts-create in a follow-up turn.]

## 📋 Raw context (for verification)

- Pinned dashboards: <list with URLs>
- Active error issues: N (X without assignee)
- Cohorts defined: N
- Feature flags active: N
- Experiments running: N
- Total events tracked: N
- Top 3 dead event families: <list>

---

_For automated context in other commands, this report's findings are also
cached at `~/.claude/cache/posthog-snapshot.json` and remain valid for 14 days._
```

## Step 5 — Persist the snapshot

After the report is rendered to the user, **write a condensed JSON snapshot** to `~/.claude/cache/posthog-snapshot.json` with the following shape. This is what `posthog-snapshot-loader.sh` reads for inclusion in `/sprint-status`, `/daily`, and `/eod-review`.

```json
{
  "timestamp": "<ISO 8601 UTC, e.g. 2026-04-14T22:30:00Z>",
  "project_name": "<project name>",
  "project_url": "<https://eu.posthog.com/project/N>",
  "critical_findings": [
    "<one-line summary, max 120 chars>",
    "..."
  ],
  "regressions": [
    "<one-line summary, max 120 chars>",
    "..."
  ],
  "wins": [
    "<one-line summary, max 120 chars>"
  ],
  "improvements": [
    "<one-line summary, max 120 chars>",
    "..."
  ]
}
```

**Limits:** at most 5 entries per array. The goal is for the snapshot to be readable in a sprint-status report without dominating it. Each entry is **one line**, no markdown formatting beyond plain text.

Use the `Write` tool to create the file. If `~/.claude/cache/` doesn't exist, create it first with `mkdir -p`.

After writing, confirm to the user: "Snapshot persisted at `~/.claude/cache/posthog-snapshot.json`. Other commands (sprint-status, daily, eod-review) will read this for the next 14 days."

## Step 6 — Optionally apply low-risk fixes

If during the analysis you found things that are **clearly low-risk to fix on the spot** and the user has approved general "implement improvements" (this is the case when invoked with no flags or with `--apply-fixes`), you may take the following actions **without further confirmation**:

- **Tag deprecated insights**: if you identified a feature as deprecated and there are insights still tracking it, add the `deprecated` tag and prepend `[DEPRECATED]` to their description (use `mcp__posthog__insight-update`).
- **Create a project-scoped annotation** marking the deprecation date (use `mcp__posthog__annotation-create`), so future analyses anchor against it.
- **Create suggested cohorts**: if you confidently identified the right behavioral filter, create them via `mcp__posthog__cohorts-create`. Limit yourself to the 5 most useful — don't flood the workspace.

For everything else (creating new insights, modifying dashboards, creating feature flags, deleting things, modifying production data) — **always ask first**. The user is the only one who can decide whether the change matches the team's conventions.

## Style guide

- **Analytical, not metric-dump.** "DAU = 142" is wrong. "DAU dropped 12% week-over-week, coinciding with the deploy on March 27 — investigate the deploy of feature X" is right.
- **Concrete recommendations.** Every finding ends with a `→ Action:`.
- **Acknowledge uncertainty.** If you can't tell whether a drop is a bug or intentional, say so explicitly: "this could be either a tracking break or a true usage drop — verify by checking PR merges this week".
- **No false positives.** If the data is too thin to support a conclusion (e.g. < 7 days of data, very low volume), say "insufficient data to conclude" rather than inventing a story.
- **Numbers belong in the body, never in the headline.** The headline is the action; the number is the evidence.
- **Respect the cache.** If a previous snapshot exists at `~/.claude/cache/posthog-snapshot.json` and is < 1 day old, ask the user "the previous snapshot is from <X> hours ago — refresh anyway?" before re-running the full analysis. Saves time and PostHog API calls.

## What this skill does NOT do

- It does not modify dashboards (only the user does that).
- It does not delete insights or events.
- It does not create feature flags or experiments — those affect production.
- It does not write to Linear, Slack, or any other system.
- It does not send notifications — the report is for the user only.
- It does not invent data when the MCP returns errors. If data is missing, the report says so explicitly in a "⚠️ Data gaps" section at the top.
