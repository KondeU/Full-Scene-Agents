# Worked Example: A Complete Workflow Skill

This is one sub-skill from the health weekly-report workflow, written end-to-end the
way `writing-skills` should produce them. Read it alongside `authoring-good-skills.md`
before writing your first skill. It shows a **consumer** sub-skill (it consumes an
upstream product) with a confirmation boundary and a scheduled trigger — the harder
case. Match this level of concreteness; don't match its exact topic.

The plan entry it was written from:

```json
{
  "id": "generate-report",
  "role": "生成周报",
  "user_goal": "把这一周的健康记录整理成一份能看懂的周报",
  "inputs_needed": ["一周的健康记录(来自数据加工)"],
  "capabilities_used": ["processing.draft_review", "interaction.weixin_result"],
  "produces": "weekly-report",
  "consumes": ["structured-records"]
}
```

Shared `context` (from the plan, same for every sub-skill):

- schedule: `weekly:SAT 08:00`, after `process-data`
- memory scope: 记住做法,不保存每周的具体数据
- delivery: 微信发给用户本人
- confirmation boundary: 输出前让用户检查
- failure handling: 数据不全时说明缺哪项,不编造
- acceptance criteria: 用户收到一份能看懂的、数据真实的周报

---

The resulting SKILL.md:

```markdown
---
name: weekly-health-generate-report
description: Use when it's time to turn a week of saved health records into a readable weekly report, on a weekly schedule or when the user asks to see this week's health summary
---

# 生成周报

## When to Use

- 到了每周固定的出报告时间(周六早上),且这一周的健康记录已经整理好。
- 用户主动说"看看这周的健康情况""出一份周报"。

不要用于:还没有任何整理好的记录时(那一步由「数据加工」完成,先等它产出)。

## Inputs

接收 `structured-records`:这一周已经整理好的健康记录,每条形如
`{ date, resting_hr, sleep_hours, steps }`。这是「数据加工」这一步的产物 —
你不需要重新读截图或原始数据。

## Workflow

1. 收齐这一周(周一到周日)的记录。统计有几天有数据、缺哪几天。
2. 按指标算出本周概览:静息心率均值、睡眠时长均值、总步数与日均步数。
   缺数据的天不计入均值,不要用 0 顶替。
3. 和上一周比(如果记得上周概览):每项标出 ↑/↓/持平,只写变化方向,不下健康结论。
4. 拟出周报草稿,结构为:本周概览 → 三项指标各一句话 → 缺失说明(如有)。
   用大白话,不用医学术语,不给诊断或建议。
5. 把草稿发给用户本人检查(确认边界:输出前让用户看)。等用户确认或提出修改。
6. 用户确认后,通过微信发给用户本人。

## Confirmation and Boundaries

- 触发:每周六早上自动运行,也可由用户主动要求。
- 记忆范围:记住"怎么出周报"这个做法和上周概览用于对比;不长期保存每天的原始健康数据。
- 交付:只发给用户本人的微信,不发给任何其他人。
- 确认边界:发送前必须让用户看过草稿。
- 超出范围的请求(如"顺便发给我家人""给点健康建议"):用一句话说明做不到,不擅自执行。

## Failure Handling

- 某几天没有记录:照常出报告,在「缺失说明」里写清缺哪几天,均值只按有数据的天算。
- 整周都没有记录:不出空报告,告诉用户这周还没有任何数据,问是否需要补录。
- 任何数值读不出:标注「缺失」,绝不编造。

## Acceptance Criteria

用户在微信收到一份能看懂的周报,数据全部来自真实记录,缺失项有说明,没有编造的数值。

## Consumes

`structured-records` — 来自「数据加工」。

## Produces

`weekly-report` — 已确认并发送的周报。
```

---

## Why this example is good — the checklist it passes

- **Description triggers only.** No "算均值、拟草稿、发微信" paraphrase — those live
  in the body, so the Agent reads the body.
- **Input is the named product.** `structured-records` is described concretely; the
  skill never says "见数据加工那一步". It stands alone.
- **Steps are concrete.** "算均值,缺的天不计入" beats "汇总数据". The field shape
  is spelled out.
- **Confirmation is an actual step (5), not just a boundary line.** The Agent can't
  miss it.
- **Boundaries are real and specific** — "只发给用户本人" rules out the exact
  over-reach (sending to family) that this domain invites.
- **No invented capability.** Only `processing.draft_review` and
  `interaction.weixin_result` are used — exactly the plan's `capabilities_used`.
- **No fabrication rule is explicit** ("绝不编造") because the domain is health data,
  where invented numbers are the worst failure.
