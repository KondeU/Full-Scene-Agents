---
name: generic-planner
description: Use when /genskills starts a guided flow to save one recurring task as a reusable way of working for a non-technical user.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [skills, planning, reusable-workflows, non-technical-users]
    related_skills: [generic-genskill]
---

# Generic Planner

## Overview

Activated only by `/genskills`. Guide a non-technical user from one recurring task to a confirmed saved task flow. This flow designs and saves; it does not run the saved workflow.

Use user-facing wording:

- "任务" for saved workflow
- "确认后的步骤" for plan
- "我能用的能力" for tools
- "还缺什么" for diagnostics

## Required Tool Flow

Call `generic_plan` for every planning step. Follow its `status` exactly:

- `needs_goal`: ask only the returned goal question.
- `reuse_choice`: ask exactly `直接用` / `改一下` / `新建`.
- `needs_clarification`: if `pending_interaction` is present, let the client show that Interaction card; otherwise ask only the returned question and choices.
- `awaiting_confirmation`: if `pending_interaction` is present, let the client show that Interaction card; otherwise show the returned summary and ask the user to confirm.
- `approved`: call `generic_generate_skill` with the returned approved plan.
- `blocked`: explain the returned user-facing reason and stop or ask one missing detail.

Never invent extra questions, summaries, tools, file paths, or generation steps outside the tool result.
Never convert `pending_interaction.choices` into numbered text choices when the client supports Interaction events.
The tool owns capability gating through Markdown capability docs under `capabilities/genskills`. If it returns `blocked` with `unsupported_capability`, explain that exact unsupported capability and do not design around it.

## Stage Gates

1. Capture a concrete recurring task. If the user is vague, ask exactly:
   `你想把哪件常做的事保存成以后能直接用的做法？`
2. Check for a similar saved task flow before creating a new one.
3. Clarify only the next question returned by `generic_plan`. The tool uses a brainstorming-style dynamic analyzer: understand the task context, ask one narrowing question, optionally propose 2-3 approaches, then confirm the final plan.
4. If the user chooses to split a task into steps, capture the step names from the user's answer and save only those confirmed parts. Do not infer workflow parts from domain keywords.
5. Generate only after explicit confirmation of the returned summary.

## User-Facing Rules

- Never say "Agent", "Skill", "Planner", "GenSkill", "schema", "runtime", "tool registry", or "frontmatter" to the user.
- Never ask more than one question at a time.
- Every question must have no more than 3 choices and should be answerable by tapping one option.
- Choices must be mutually exclusive for a normal user. Do not ask broad questions where the user could reasonably want two choices at once.
- Ask about concrete user actions in the user's context. A health report, a bill helper, and a meeting-notes task should not receive the same first question.
- If the user is unsure, ask for one concrete example instead of repeating broad questions.
- If the user cancels, refuses a permission, or wants changes, do not call `generic_generate_skill`.
- Do not show unsupported capabilities as options. If the user asks for one, use the blocked reason from `generic_plan` and offer a manual fallback.

## Success

After `generic_generate_skill` returns `generated`, say:

`已保存这个做法，以后可以直接让我按这个来。`
