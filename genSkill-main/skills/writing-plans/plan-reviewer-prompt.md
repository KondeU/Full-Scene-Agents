# Plan Review Checklist

Use this checklist to review a plan before asking the user to approve it.

**Purpose:** Verify the structured plan is complete, stays inside system capabilities, and that the plain-language description leaks no system terms — before the user is asked to approve.

**How to run it:** By default, do this review **inline yourself** — walk the
"What to Check" table below against your plan JSON and plain-language text. This
works in every runtime. If your runtime has a Task/subagent tool (e.g. Claude
Code) you *may* dispatch an independent reviewer with the prompt below, but never
block on a subagent result — many runtimes (openclaw) have no such tool, and a
hand-off that never returns will stall the whole flow. When in doubt, review
inline and move on.

**Run after:** The structured plan (Step 1) is drafted and the plain-language version (Step 2) is written, but BEFORE asking the user to approve (Step 3).

## What to Check

Walk this table against your plan JSON and plain-language text (the same criteria
apply whether you review inline or hand it to a subagent):

| Category | What to Look For |
|----------|------------------|
| Field completeness | Every top-level field present and filled: user_goal, inputs_needed, schedule_or_trigger, memory_scope, output_or_delivery, confirmation_boundary, failure_handling, acceptance_criteria, capabilities_used. No empty values, no "TBD". Plus EITHER a `skills[]` array (each entry having id, role, user_goal, inputs_needed, capabilities_used, produces, consumes) OR — for a single-action legacy plan — a flat `steps[]`. Do NOT require `steps` on a `skills[]` plan; sub-skill workflow detail is authored later in writing-skills, not in the plan. |
| Capability compliance | Every ID in capabilities_used (and in each `skills[].capabilities_used`) is listed under **Supported** in ../genSkill/references/capabilities-summary.md. Flag any disabled or invented capability. |
| Capability coverage | Every sub-skill in `skills[]` (or every step in a legacy `steps[]`) is achievable by a listed capability. Flag any sub-skill/step that needs a capability not in the system. |
| Data-contract consistency | For each `consumes` edge, the producing sub-skill's `produces` exists and its `produces_shape` (when present) contains every field the consumer needs. Flag a consumer that reads a field its upstream `produces_shape` does not provide, or a consumer reading structured fields off a producer that has no `produces_shape`. |
| Plain-language purity | No system terms (记忆边界, 能力边界, schema, trigger), no capability IDs, no English technical terms (unless the user wrote in English). |
| Boundary honesty | "我不会做的事" lists real boundaries derived from confirmation_boundary, not generic disclaimers. |
| Plan ↔ plain-language match | The plain-language description faithfully reflects the structured plan — no step shown to the user that the plan doesn't contain, and no plan step silently hidden. |

## Calibration

**Only flag issues that would produce a wrong or unsafe Skill, or mislead the user.**
An unsupported capability, a missing field, a leaked system term, or a fabricated
boundary is an issue. Minor wording polish is not.

The plan is clean unless there are real gaps — missing/empty fields, unsupported
or invented capabilities, a step no capability can perform, system terms or
capability IDs leaking into the plain-language text, or a mismatch between the two
representations. Fix any gap, then re-check before proceeding.

## Optional: Dispatch as a Subagent

If (and only if) your runtime has a Task/subagent tool, you may hand the review to
an independent reviewer instead of doing it inline. Pass the structured plan JSON,
the plain-language description, and the path to `../genSkill/references/capabilities-summary.md`,
wrapped in this prompt. **Do not block on the result** — if no subagent tool
exists, skip this entirely and review inline.

```
You are reviewing a genSkill plan. A structured plan and its plain-language
translation will be handed to a generator script and shown to a non-technical user.
Verify both are ready, using the "What to Check" table and "Calibration" notes above.

Structured plan (JSON): [PLAN_JSON]
Plain-language description: [PLAIN_LANGUAGE_TEXT]
Capability reference: ../genSkill/references/capabilities-summary.md

Return:
**Status:** Approved | Issues Found
**Issues (if any):**
- [field / step / line]: [specific issue] - [why it would break generation or mislead the user]
**Recommendations (advisory, do not block approval):**
- [suggestions for improvement]
```
