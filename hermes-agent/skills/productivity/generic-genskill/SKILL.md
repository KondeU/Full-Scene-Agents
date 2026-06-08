---
name: generic-genskill
description: Use after a /genskills plan is approved to save the confirmed recurring task as a Hermes SKILL.md.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [skills, authoring, reusable-workflows]
    related_skills: [generic-planner, hermes-agent-skill-authoring]
---

# Generic GenSkill

## Overview

Use this skill only after `generic_plan` returns `status: approved`. Treat the returned approved plan as the only source of truth. A confirmed plan may produce one reusable way of working or a bundle of child reusable ways plus one orchestrator.

This skill is for internal execution. User-facing text should say "保存这个做法", not "generate a Skill".

## Preconditions

- The plan came from `generic_plan`.
- The plan has `approved: true`.
- The plan names the recurring task, needed inputs, trigger/timing, output, confirmation boundary, and missing-input behavior.
- Risky actions preserve explicit user confirmation.

## Workflow

1. Call `generic_generate_skill` once with the approved plan. If the plan contains multiple parts, still call it once with the whole plan.
2. Never manually write, patch, or save a `SKILL.md`.
3. Handle the result with this decision table:
   - `generated`: summarize the saved reusable way of working in plain language. If multiple skills were saved, describe them as one reusable workflow with several parts.
   - `blocked`: explain the user-facing reason and ask for exactly one missing detail at a time, using the shortest question that would unblock generation.
   - Any other status, error, timeout, partial result, or tool failure: stop and report the tool failure as returned; do not claim success or ask for unrelated details.

## Validation Rules

- `generic_generate_skill` owns validation for frontmatter, stable names, existing tools, required sections, name conflicts, and all-or-nothing bundle writes.
- If validation blocks, do not retry more than once and do not claim that anything was saved.
- Do not expose output paths unless the user asks.
- Do not present test-only, missing, or unavailable external services as real user-facing capability.

## Success Message

When generation succeeds, tell the user:

`已保存这个做法，以后可以直接让我按这个来。`
