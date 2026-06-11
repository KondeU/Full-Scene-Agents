---
id: trigger.scheduled_reminder
domain: task_trigger
label: 按固定时间自动执行
status: supported
user_words: [定时, 每天, 每周, 每月, 固定时间, 定时执行, 提醒]
---

按用户确认的固定时间,在 openclaw 注册一个定时任务(cron),到点由 cron 给 Agent
发一条消息,自动触发对应技能执行——既可以是"提醒用户来处理",也可以是"无人值守
地跑完某个技能,再把结果通知用户"。

注册方式(由生成阶段落地,不需要用户手动敲):

```
openclaw cron add \
  --cron "0 9 * * 0" \
  --announce \
  --message "调用<生成报告技能>,生成本周健康周报;完成后通过<已确认的channel>通知我。"
```

- `--cron` 用标准 cron 表达式(5 段:分 时 日 月 周;也支持 6 段带秒)。
- `--message` 是到点时发给 Agent 的指令,内容必须只引用本流程已批准的技能和已确认
  的通知 channel,不得超出批准范围。
- `--announce` 让结果汇报到聊天;需要等技能跑完整结果再通知时加 `--expect-final`。

边界:
- 只能触发本次流程里已批准的技能;cron 消息不能让 Agent 做批准范围外的事。
- 到点执行的动作若涉及对外发送,仍受对应 channel 能力的边界约束(如 `interaction.weixin_result`)。
- 不能替用户完成外部应用里需要其本人操作的步骤(登录、付款、改账号等)。
