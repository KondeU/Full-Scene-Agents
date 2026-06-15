# A2UI Emit Guide — `intentx.app:cards@1`

> For genSkill phases. When the client advertises support for catalog
> `intentx.app:cards@1`, emit a structured card **instead of** the equivalent
> prose at each structured moment. When the client does NOT advertise it, fall
> back to plain text exactly as before. This is the only thing that decides
> whether a turn renders as UI — the client never guesses.

## How to emit

Put **one** fenced block in your reply. Any human lead-in goes *outside* the
block (it renders as a normal bubble above the card):

````
好的，先了解一下细节。
```a2ui
{"createSurface":{"surfaceId":"clarify-1","catalogId":"intentx.app:cards@1"}}
{"updateComponents":{"surfaceId":"clarify-1","components":[{"id":"root","component":"ClarifyQuestion","phase":"clarify","questionIndex":1,"totalQuestions":3,"question":"你希望什么时候生成这份周报？","options":[{"id":"1","label":"定时自动生成","description":"比如每周日晚上"},{"id":"2","label":"我想看的时候自己开口要"}],"action":{"name":"clarifyAnswer"}}]}
```
````

Rules:
- `catalogId` MUST be `intentx.app:cards@1`. `component` MUST be one of the 6 below — **never** A2UI standard components (Text/Row/Column/Button/…).
- One `createSurface` + one `updateComponents` per card. The single component has `"id":"root"`.
- Keep option/approach labels **short**; put explanation in `description`/`body`.
- If the client returns a validation error, fix only the cited fields and re-emit the one block.

## Component cheat-sheet (one per structured moment)

| Phase | Component | Required fields | Sent back on action |
|---|---|---|---|
| clarify (Q) | `ClarifyQuestion` | `phase:"clarify"`, `question`, `options[2..3]{id,label}`, `action{name}` | chosen option's `label` |
| clarify (end) | `ApproachProposal` | `phase:"clarify"`, `approaches[2..3]{id,title}`, `action{name}` | chosen approach `id` (A/B/C) |
| customize | `PlanConfirm` | `phase:"customize"`, `taskTitle`, `items[]{label,value}`, `question`, `confirmAction{name}` | `可以` on confirm |
| create | `SkillCreate` | `phase:"create"`, `steps[]{id,status:done|error,label}` | — (progress only) |
| execute | `ExecuteSummary` | `phase:"execute"`, `skillPaths[]` (+ `usageSteps[]`, `cta`) | — |
| any | `AgentText` | `markdown` | — (fallback bubble) |

Optional fields: `ClarifyQuestion.preamble/questionIndex/totalQuestions/options[].description`;
`ApproachProposal.preamble/recommendedId/approaches[].body`; `SkillCreate.steps[].detail/annotations[]`;
`ExecuteSummary.intro/usageSteps/cta/ctaAction`.

## Per-phase mapping (genSkill)

- **Phase 1 question** (genSkill, one dimension, ≤3 choices) → `ClarifyQuestion`. The
  card's options are the same numbered choices the prose would have listed; the
  client sends the chosen label back, so the server sees the same answer as a typed reply.
- **Phase 1 close** (2-3 approaches + recommendation) → `ApproachProposal` with `recommendedId`.
- **writing-plans** plan confirmation (the "用户交互流程描述" + "这样创建可以吗？") →
  `PlanConfirm`: `taskTitle` = the goal; `items` = the 6 plain-language lines
  (你给我 / 我会 / 开始方式 / 完成后 / 如果缺东西 / 我不会做的事); `question` = "这样创建可以吗？".
- **writing-skills** file writes → one `SkillCreate` with a `steps[]` entry per
  written file (`status:"done"`, `label:"写入 <最后两段路径>"`); failures as
  `status:"error"` with the raw output in `detail`. Errors do not block.
- **execute** final summary → `ExecuteSummary`: `skillPaths` = created SKILL.md
  paths; `usageSteps` = the usage list; `cta` = the closing call-to-action.

## Capability negotiation

The client declares support during handshake (A2UI `clientUiCapabilities` with
`catalogId: intentx.app:cards@1`). Only emit A2UI when that support is present;
otherwise emit the plain-text form. Runtimes without a renderer (web/CLI) thus
never see raw JSON.
