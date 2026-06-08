# OpenClaw Node 能力发现与对接指南

> HarmonyOS Node 如何向 OpenClaw Gateway 声明能力，以及 AI Agent 如何发现并调用这些能力。
> 基于端侧实现 + Gateway `node-registry.ts`/`server-methods/nodes.ts` 源码 + [官方协议文档](https://docs.openclaw.ai/gateway/protocol) 交叉验证。

---

## 一、架构

```
                     连接时宣告                         运行时
┌──────────────┐  caps + commands      ┌───────────┐  node.list/describe
│ HarmonyOS    │ ────────────────────→ │  Gateway  │ ←──── AI Agent
│  Node        │                       │           │
│              │ ←──────────────────── │           │ ──→  Operator
│              │  node.invoke 路由      │ NodeRegistry
└──────────────┘                       └───────────┘
```

**核心原则**：Gateway 只做路由转发，不知命令参数语义。

---

## 二、Node 宣告能力（端侧）

### 2.1 协议 Schema

`src/gateway/protocol/schema/nodes.ts:12-28` — connect 时发送 `caps`（能力类别）和 `commands`（命令列表）：

```typescript
const NodePairRequestParamsSchema = Type.Object({
  caps: Type.Optional(Type.Array(NonEmptyString)),      // 如 ["device", "card"]
  commands: Type.Optional(Type.Array(NonEmptyString)),  // 如 ["device.status", "card.reminder.update"]
  // ... nodeId, platform, version, deviceFamily ...
});
```

### 2.2 端侧实现路径

| 文件 | 职责 |
|------|------|
| `OpenClawProtocolConstants.ets` | 定义 `OpenClawCardCommand.ReminderUpdate = 'card.reminder.update'` |
| `InvokeCommandRegistry.ets` | `all` 注册 + `advertisedCommands()` 条件宣告 |
| `NodeInvokeDispatcher.ets` | `switch(command)` 路由到 `cardReminderService.handleUpdateReminderCommand()` |
| `CardReminderService.ets` | 解析 JSON params → `updateReminderCard()` → `pushToAllForms()` |

### 2.3 发送的 connect JSON

```json
{
  "method": "connect",
  "params": {
    "role": "node",
    "caps": ["device", "card"],
    "commands": ["device.status","device.info","device.permissions","device.health","card.reminder.update"],
    "client": { "id": "openclaw-harmonyos", "mode": "node" }
  }
}
```

### 2.4 与原始设备命令的对齐

`card.reminder.update` 与 `device.status`/`device.info` 等原始命令在五个环节完全一致：

```
常量定义 → all 注册 → 条件宣告 → dispatcher switch → 返回值格式
```

唯一区别：卡片命令需解析 params + 有副作用（图片下载/表单推送），委托给 `CardReminderService`。

---

## 三、Gateway 存储与路由

### 3.1 Node 注册

`src/gateway/node-registry.ts` — `NodeSession` 存储 `caps: string[]` 和 `commands: string[]` 为纯字符串数组。

### 3.2 查询接口

| 方法 | 用途 |
|------|------|
| `node.list` | 返回所有已配对 Node（含离线），合并 live session + 配对记录 |
| `node.describe` | 单个 Node 详细信息 |
| `node.invoke` | `NodeInvokeParamsSchema` 中 `params: Type.Unknown()` — **Gateway 不解析参数** |

### 3.3 `node.invoke` 两步门控

1. 命令必须在 Node 宣告的 `commands` 列表中
2. 通过 Gateway 的 `allowCommands/denyCommands` 策略

---

## 四、Agent 工具：`nodes` 工具的对接

### 4.1 所有能力都有专属 action + 类型化参数

Agent 通过 `src/agents/tools/nodes-tool.ts` 中的 `nodes` 工具调用节点能力。**所有第一公民能力都是专属 action，不是原始 `invoke`**：

```typescript
const NODES_TOOL_ACTIONS = [
  "status", "describe", "pending", "approve", "reject",
  "notify",        // → system.notify
  "camera_snap",   // → camera.snap
  "camera_list", "camera_clip",
  "photos_latest", // → photos.latest
  "screen_record", // → screen.record
  "location_get",  // → location.get
  "notifications_list", "notifications_action",
  "device_status", "device_info", "device_permissions", "device_health",
  "card_reminder_update",  // → card.reminder.update
  "invoke",        // 通用 escape hatch
] as const;
```

每个 action 对应 `NodesToolSchema` 中的 TypeBox 类型化参数。Agent 看到类型化参数后无需猜测格式。例如：

- `location_get` 有 `maxAgeMs`/`desiredAccuracy`/`locationTimeoutMs`
- `notify` 有 `title`/`body`/`sound`/`priority`/`delivery`
- `card_reminder_update` 有 `cardTitle`/`cardBody`/`cardNote`/`cardImageUrl`

### 4.2 TypeBox schema 参数描述

TypeBox schema 直接编译为 JSON Schema 传给 LLM。`Type.String({ description: "..." })` 中的 description 会出现在 Anthropic `input_schema.properties.X.description` 中。OpenClaw 官方插件工具指南明确推荐加 description。

`nodes-tool.ts` 现有参数大多省略了 description（只有 `facing` 有），这是历史遗留。`card_reminder_update` 的四个参数已补全：

```typescript
cardTitle: Type.Optional(Type.String({ description: "Optional card title shown above the body" })),
cardBody: Type.Optional(Type.String({ description: "Main card body text, bold and darkest, max 3 lines" })),
cardNote: Type.Optional(Type.String({ description: "Optional footer note below the body" })),
cardImageUrl: Type.Optional(Type.String({ description: "Optional right-side image URL (http/https)" })),
```

### 4.3 Agent 调用示例

```json
{
  "action": "card_reminder_update",
  "node": "harmonyos-xxx",
  "cardTitle": "会议提醒",
  "cardBody": "15:00 产品评审",
  "cardNote": "会议室 A"
}
```

### 4.4 完整调用链路

```
AI Agent
  ├─→ nodes action="status"
  │     → node.list → 发现节点有 "card" 能力 + "card.reminder.update" 命令
  ├─→ nodes action="card_reminder_update" {cardTitle, cardBody, cardNote, cardImageUrl}
  │     → node.invoke{command:"card.reminder.update", params:{title,body,note,imageUrl}}
  │       → Gateway 路由 → NodeInvokeDispatcher → cardReminderService
  │     ← { "ok": true }
  └─→ 卡片已更新
```

---

## 五、`card.reminder.update` 命令规范

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `title` | string | 否 | 卡片标题，14fp 显示在正文上方 |
| `body` | string | **是** | 正文内容，17fp 加粗深色，最多 3 行 |
| `note` | string | 否 | 底部备注，14fp |
| `imageUrl` | string | 否 | 配图 URL（http/https） |

### 返回值

```json
{ "ok": true, "formIdsCount": 1 }
```

---

## 六、对接改动清单

| 层 | 文件 | 改动 |
|------|------|------|
| 协议常量 | `ets/protocol/OpenClawProtocolConstants.ets` | 新增 `OpenClawCardCommand.ReminderUpdate` |
| 注册表 | `ets/node/InvokeCommandRegistry.ets` | all 注册 + `advertisedCommands()` 新增 |
| 分发器 | `ets/node/NodeInvokeDispatcher.ets` | switch case 新增 |
| 处理器 | `ets/service/CardReminderService.ets` | `handleUpdateReminderCommand()` |
| Gateway Agent 工具 | `src/agents/tools/nodes-tool.ts` | `card_reminder_update` action + TypeBox params + handler |
