---
name: genSkill:brainstorming
description: Use as the first phase of /genSkill. Clarifies user intent through one-at-a-time narrowing questions until the goal, inputs, trigger, output, and failure handling are all understood.
---

# Brainstorming

Help the user clarify what they actually want to save as a reusable workflow. Do not design the solution — just understand the intent.

## Hard Rules

1. One question per turn. No exceptions.
2. Each question has at most 3 choices, numbered. Choices must be mutually exclusive — if a user could reasonably want two options at once, reframe the question.
3. Questions must address concrete user behavior ("你会怎么告诉我信息？" / "你想先看到什么结果？"), not system internals ("能力边界"/"权限"/"schema").
4. Do not show capabilities the system cannot do (check `references/capabilities-summary.md` — that one file is enough for this phase). If the user asks for a disabled one, explain which part is not possible and offer a workable alternative.
5. If the user gives a free-text answer, the next question must build on that answer. Never fall back to a generic template questionnaire.
6. Do not give a premature summary. Only present a "用户交互流程描述" after all necessary questions are answered.
7. Follow the rhythm: **understand context → ask one narrowing question → (repeat until converged) → propose 2-3 approaches → user picks one → exit**.

## Question Design Principles

- Ask about the user's concrete actions first: "你会怎么把信息给我？" not "输入模态是什么？"
- Prefer "你想先得到什么" over "能力边界是什么"
- Choices must be things a normal person can immediately understand and distinguish
- If you need to know about timing, ask "你希望什么时候用这个？" not "触发条件是什么？"
- If the user answers vaguely, ask for one concrete example instead of repeating the question

## Process

```
User states goal
  → Is the goal clear enough to start asking details?
    → No: ask one question to sharpen the goal
    → Yes: begin narrowing questions

For each turn:
  1. Identify the single biggest gap in your understanding
  2. Formulate one question that closes that gap
  3. Provide 2-3 mutually exclusive choices (or allow free text if choices would be forced)
  4. Wait for the user's answer
  5. If the answer opens a new direction, follow it — do NOT return to a pre-planned sequence

When all gaps are filled:
  → Propose 2-3 approaches with trade-offs and your recommendation
  → User picks one
  → Exit to writing-plans phase
```

## What Counts as "All Gaps Filled"

You can exit brainstorming when you can answer ALL of these without guessing:

- **Goal**: What does the user want to accomplish?
- **Inputs**: What will the user provide each time?
- **Trigger**: How should the task start?
- **Output**: What result does the user want to see?
- **Failure**: What should happen if something is missing?

If any of these is still unclear, ask one more narrowing question.

## Anti-Patterns

| If you catch yourself doing this... | Stop and do this instead |
|------|------|
| Asking a question with non-mutually-exclusive options | Reframe as a more specific question where options don't overlap |
| Showing more than 3 options | Pick the 3 most likely, or ask a narrower question |
| Asking about "schema" / "能力" / "触发条件" | Rephrase in the user's language |
| Presenting a summary before all gaps are filled | Ask the next narrowing question first |
| Offering a template question after user free-text input | Build directly on what they said |
| Following a pre-planned question sequence | Each question must respond to the previous answer |
| Asking "还有别的需求吗？" as a catch-all | Ask about the specific gap you still see |

## Exit Condition

Brainstorming is complete when:
1. All five gaps (goal, inputs, trigger, output, failure) are answered
2. You have proposed 2-3 approaches
3. The user has picked one approach

**Next step**: Invoke `genSkill:writing-plans` with the brainstorming outcome.
