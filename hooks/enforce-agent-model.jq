# PreToolUse hook filter (matcher: Agent). Blocks Agent calls without an explicit model param.
# Companion to ~/.claude/skills/model-routing/SKILL.md: without model, subagents inherit the
# expensive session model (Fable). Emits a deny decision so the model retries with model set.
if (.tool_input.model // "") == "" then
  {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Agent call blocked: missing required model param (subagents inherit the expensive session model otherwise). Retry the SAME Agent call adding model per the model-routing skill: sonnet (exploration, research, bounded implementation), haiku (mechanical reduction, log/test triage, inventories), opus (risky implementation, code review, adversarial verification). Use fable only if judgment itself must run in a subagent."
    }
  }
else
  empty
end
