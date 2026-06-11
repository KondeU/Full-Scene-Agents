# Capabilities Summary

This is the **first layer** of capability disclosure. Read **only this file** for
the brainstorming and writing-plans phases — do NOT read the per-capability files
in `capabilities/` until the writing-skills phase needs exact boundary text.

It answers two questions:
1. What capabilities exist (grouped by domain).
2. Which are supported and which are disabled right now.

Each row: `id` — `label` (the everyday words a user might say).

## Supported (may appear as options / in a plan)

### task_trigger — 怎么开始
- `trigger.manual` — 我需要时手动点开始 (手动, 点开始, 需要时)
- `trigger.scheduled_reminder` — 按固定时间自动执行 (定时, 每天, 每周, 每月, 定时执行, 提醒) — 经 openclaw cron 到点触发技能,可无人值守执行后再通知
- `trigger.decide_later` — 先保存，执行时再说 (以后再说, 先保存)

### input_information — 用户怎么给信息
- `input.typed_text` — 文字说明 (文字, 文本, 手动输入)
- `input.photo_or_screenshot` — 拍照或截图 (拍照, 截图, 照片)
- `input.file_or_image_attachment` — 文件或图片附件 (文件, 附件, 上传)

### information_processing — 怎么处理材料
- `processing.extract_key_fields` — 提取关键信息 (提取, 识别, 抓取)
- `processing.structure_record` — 整理成结构化记录 (整理, 结构化, 记录, 表单)
- `processing.draft_review` — 生成草稿给我检查 (草稿, 报告, 初稿)

### user_interaction — 怎么呈现结果
- `interaction.chat_result` — 在聊天里给一份结果 (聊天, 结果, 回复)
- `interaction.weixin_result` — 使用微信通知用户结果 (微信, 结果, 回复)
- `interaction.table_or_list` — 整理成表格或清单 (表格, 清单, 列表)
- `interaction.choice_cards` — 用选项让我确认 (选择题, 按钮, 选项) — 每张卡片最多 3 个互斥选项
- `interaction.a2ui_widget` — 生成式 A2UI Widget (A2UI, Widget, 卡片UI, 小组件)

### task_memory — 记住什么
- `memory.workflow_only` — 只保存流程，不保存具体数据 (不保存数据, 只保存流程)
- `memory.confirmed_preferences` — 记住我确认过的偏好或字段 (记住偏好, 保存字段, 记住规则)
- `memory.data_store` — 经确认后写入长期记忆并持久化 (记住, 保存数据, 存起来, 长期记忆, 留存, 历史数据, 召回) — 用写入长期记忆的指令+格式化数据持久化,逐次确认,供以后召回
- `memory.ask_each_time` — 每次执行时再问 (每次问, 执行时再问, 临时决定)

### sensed_state — 自动感知
- `sensed.geofence` — 地理围栏 (到某地, 离开某地, 位置触发)

## Disabled (NEVER offer as an option; if user asks, explain + offer the alternative)

### external_actions — 替用户操作外部系统
- `external.payment` — 付款或转账 → 替代：整理账单信息，交给用户自行处理
- `external.send_message` — 主动发送给别人 → 替代：生成待发送内容，用户确认后自己发
- `external.delete_or_publish` — 删除或发布外部内容 → 替代：给出建议、草稿或检查清单
- `external.account_change` — 修改账号或外部系统 → 替代：整理步骤或说明，让用户自行操作

### sensed_state — 自动感知
- `sensed.health_data_read` — 健康数据读取 → 替代：用户手动输入或截图提供
- `sensed.calendar_read` — 日历读取 → 替代：用户把日程内容发到聊天里

## When you DO need the per-capability file

Only in **writing-skills** (or when the fallback path asks you to gate by hand):
read `capabilities/<file>.md` for the exact 边界 / 替代方式 wording of the specific
capabilities a plan uses. The summary above is enough for goal clarification,
option-proposing, and plan feasibility — everything before writing-skills.
