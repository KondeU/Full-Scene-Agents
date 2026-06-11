# Authoring Good Workflow Skills

Read this before writing any SKILL.md in `writing-skills`. It is the craft layer:
how to turn one approved sub-task into a SKILL.md an Agent can run end-to-end with
no other context.

These skills are **workflow runbooks for end users** (import data, build a weekly
report, render a widget) — not discipline-enforcing skills like TDD. So the craft
here is "write a procedure another Agent can follow correctly," not "resist
rationalization under pressure." Borrow the structure and the description rule;
ignore anything about failing-test-first or red-flag tables — that machinery is for
a different kind of skill.

## The One Rule That Breaks Skills If You Get It Wrong

**`description` = when to use, NOT what it does.**

The Agent reads the description to decide whether to load the skill. If the
description summarizes the workflow, the Agent follows the summary and skips the
body — testing shows this repeatedly. A skill whose description says "imports data,
extracts fields, and writes a record" gets executed as that one-line paraphrase;
the careful steps you wrote go unread.

```yaml
# BAD — summarizes the workflow, body gets skipped
description: Imports a health screenshot, extracts metrics, and saves a record

# BAD — too abstract, never triggers
description: For health data

# GOOD — only triggering conditions
description: Use when the user sends a health screenshot or types in metrics to be saved for the weekly report
```

Start with "Use when…". Describe the situation that should trigger the skill, in
the everyday words a user would say. Stop there.

## Body Structure

Every workflow skill follows the same shape (the required headings are set in
`writing-skills`; this is how to fill them well):

- **`# <role>`** — the human label from the plan (`导入数据`), not the slug.
- **`## When to Use`** — concrete triggers and symptoms. When NOT to use, if there's
  a sibling skill it could be confused with.
- **`## Inputs`** — exactly what comes in. For a consumer skill, the input IS the
  upstream product — name it ("接收 `raw-input`:一张健康截图或一段文字"), don't
  assume the producer's SKILL.md is open.
- **`## Workflow`** — the real work. See "Writing the Workflow" below.
- **`## Confirmation and Boundaries`** — trigger/schedule, memory scope, delivery,
  confirmation boundary. State that out-of-scope requests get one clarifying
  question or a plain refusal.
- **`## Failure Handling`** — what to do when an input is missing or malformed.
- **`## Acceptance Criteria`** — how the user knows it worked.
- **`## Produces` / `## Consumes`** — product ids, so `execute` can chain skills.

## Writing the Workflow (the part only you can write)

The plan deliberately left the steps out. Your job is to make them concrete enough
that an Agent with no other context follows them correctly.

**Be specific about data shape.** "提取关键字段" is useless. Say which fields, from
what, into what shape:

```
BAD:   1. 提取关键字段
GOOD:  1. 从截图里读出这几项:日期、静息心率、睡眠时长、步数。
          读不到的项标记为「缺失」,不要编造数值。
       2. 整理成一条记录:{ date, resting_hr, sleep_hours, steps }
```

**Numbered, ordered, runnable.** Each step is one action. If a step has a branch,
state both arms ("如果用户给的是文字而不是截图,跳过 OCR,直接解析文字").

**Name the confirmation point inline.** If the plan's `confirmation_boundary` says
"输出前让用户检查", put that as an actual step ("把整理好的记录给用户看,确认无误
再保存"), not just in the boundaries section.

**Stay inside `capabilities_used`.** Do not introduce a capability the plan didn't
list. If the workflow seems to need one, that's a plan problem — go back to
`writing-plans`, don't write around it.

## Keyword Coverage

Pull the everyday words a user would actually say into the description and `When to
Use` — sourced from the capability files' `user_words` and the sub-skill `role`. A
skill that's never found is dead weight. For the health import skill: "截图"、"健康
数据"、"心率"、"睡眠"、"步数" all belong in the trigger text.

## Keep It Tight

These skills load when triggered, so length costs. One clear path beats an
exhaustive one. Don't document every edge case the plan didn't ask for; don't repeat
the boundaries in three sections; don't explain what's obvious from the step itself.
Aim for a body a person can scan in under a minute.

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Description paraphrases the workflow | Description is triggers only; workflow lives in the body |
| "提取关键字段" (vague) | Name the fields, source, and output shape |
| Consumer skill assumes producer is "open" | Names the upstream product as a concrete input |
| Narrative ("上次我们是这样做的…") | Reusable procedure, present tense, no story |
| Inventing a capability mid-workflow | Only `capabilities_used`; gaps go back to `writing-plans` |
| Repeating boundaries in every section | State each boundary once, where it belongs |

A complete worked example follows in `authoring-good-skills-example.md` — read it
before writing your first skill of a workflow.
