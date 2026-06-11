# HarmonyOS Node 能力调用指南

> 面向 OpenClaw Agent：本指南描述 HarmonyOS 设备 Node 暴露给智能体的 Tool 能力，包括 CLI 调用格式和参数说明。

---

## 快速参考

| 能力 | Command | CLI 示例 |
|------|---------|---------|
| 推送桌面卡片 | `card.reminder.update` | `openclaw nodes invoke --node <id> --command card.reminder.update --params "..."` |
| 获取设备位置 | `location.get` | `openclaw nodes invoke --node <id> --command location.get --params "..."` |
| 发送通知 | `system.notify` | `openclaw nodes invoke --node <id> --command system.notify --params "..."` |

> `--node <id>` 通过 `openclaw nodes list` 获取设备节点 ID。

---

## 一、推送桌面卡片 (`card.reminder.update`)

### 1.1 概述

向 HarmonyOS 设备桌面 2×4 服务卡片推送内容。Agent 通过 `style` 参数选择两种渲染风格。

### 1.2 信息展示卡 (`infoShowTitleBodyNoteImage`，默认)

左文字右缩略图的经典信息展示布局。`style` 不传时默认使用此风格。

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params \
  "{\"title\":\"会议提醒\",\"body\":\"下午3:00 产品评审，A304\",\"note\":\"请准备演示材料\",\"imageUrl\":\"\"}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `body` | **是** | 正文，卡片核心文字 |
| `title` | 否 | 标题行，浅色小字 |
| `note` | 否 | 备注行，浅色小字 |
| `imageUrl` | 否 | 右侧缩略图 URL（132×120vp）。有图时文字区压缩，无图时文字区占满 |
| `skill` | 否 | 拍照/选图后发给 chat 的技能指令，见 1.4 节 |

### 1.3 图片导入卡 (`infoShowTitleImageAndImport`)

全幅背景图 + 右侧两个半透明按钮（"拍一拍"/"选一选"），引导用户拍照或选图导入。

**有背景图：**

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params \
  "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"今天的健康餐\",\"imageUrl\":\"https://example.com/meal.jpg\"}"
```

**无背景图（纯文字+按钮）：**

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params \
  "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"拍一张今天的午餐吧\"}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `body` | **是** | 正文，卡片左上角文字 |
| `imageUrl` | 否 | 背景图 URL。有图时全幅铺满，无图时白底 |
| `title` | — | 此风格下忽略 |
| `note` | — | 此风格下忽略 |
| `skill` | 否 | 拍照/选图后发给 chat 的技能指令 |

**按钮行为**：
- **拍一拍**：拉起 App 到导入页，自动打开相机拍照
- **选一选**：拉起 App 到导入页，自动打开相册选取

### 1.4 `skill` 参数（图片导入后的文本指令）

`skill` 不参与卡片渲染。用户通过卡片按钮拍照或选图后，skill 决定图片附件附带的消息文本。

| skill 值 | 发送给 chat 的文本 |
|----------|-------------------|
| 空 / 不传 | `/ImageData`（默认） |
| `"数据录入"` | `/skill 数据录入` |
| `"健康记录"` | `/skill 健康记录` |

```bash
# 拍照后自动发送 /skill 数据录入 + 图片附件
openclaw nodes invoke --node <id> --command card.reminder.update --params \
  "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"拍体检报告\",\"skill\":\"数据录入\"}"
```

### 1.5 交互流程

```
Agent 发送 card.reminder.update
  → Gateway WebSocket → HarmonyOS Node 接收
  → CardReminderService 下载图片(如有) → formProvider.updateForm()
  → 桌面卡片渲染新内容
  → 用户点击"拍一拍"/"选一选"
  → App 打开导入页 → 拍照/选图 → 图片压缩 → sendChat(msgText, [image])
  → msgText = skill非空 ? "/skill <name>" : "/ImageData"
```

**注意事项**：
- 图片 URL 必须可公网访问（非 `file://` 或 `content://`）
- 图片下载失败时卡片降级为无图模式
- App 必须在前台（Gateway 连接活跃）才能接收 invoke；后台时 invoke 会超时

---

## 二、获取设备位置 (`location.get`)

### 2.1 概述

获取 HarmonyOS 设备的当前地理位置（单次定位）。受用户隐私偏好控制。

### 2.2 调用方式

```bash
openclaw nodes invoke --node <id> --command location.get --params \
  "{\"desiredAccuracy\":\"precise\",\"timeoutMs\":10000}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `desiredAccuracy` | 否 | 定位精度。`"precise"`（默认，高精度）、`"balanced"`（均衡）、`"coarse"`（低功耗） |
| `timeoutMs` | 否 | 定位超时（毫秒），默认 10000 |
| `maxAgeMs` | 否 | 缓存有效期。当前版本不支持缓存定位 |

### 2.3 返回结构

```json
{
  "latitude": 31.2304,
  "longitude": 121.4737,
  "altitude": 4.5,
  "accuracy": 15.0,
  "timestamp": 1718000000000
}
```

### 2.4 隐私控制

- 用户可在导入页面设置位置偏好：`Approximate`（粗略）或 `Off`（关闭）
- 设为 `Off` 时返回错误 `LOCATION_DISABLED`
- 设为 `Approximate` 时自动使用 `balanced` 精度
- 图片 URL 下载失败的图片不会发送，消息仅带文本

---

## 三、发送通知 (`system.notify`)

### 3.1 概述

向 HarmonyOS 设备系统通知栏推送通知。点击通知可拉起 App。

### 3.2 调用方式

```bash
openclaw nodes invoke --node <id> --command system.notify --params \
  "{\"title\":\"Agent 通知\",\"body\":\"您的任务已完成\",\"priority\":\"active\",\"sound\":\"\"}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `title` | **是** | 通知标题 |
| `body` | **是** | 通知正文 |
| `priority` | 否 | `"active"`（默认，高优先级）、`"passive"`（低优先级）、`"timeSensitive"`（时效性） |
| `sound` | 否 | 空字符串=系统默认声音，`"none"`/`"silent"`=静音 |

### 3.3 行为说明

- 应用在前台时**不弹出系统通知**（Agent 回复已在聊天页面可见），返回 ok 但跳过 publish
- 通知点击后自动拉起 App 的 EntryAbility
- 通知 ID 使用自增计数器，避免并发冲突

---

## 附：`openclaw nodes invoke` 通用格式

```
openclaw nodes invoke --node <node-id> --command <command> --params "<json>"
```

| 选项 | 说明 |
|------|------|
| `--node` | 目标设备节点 ID（来自 `openclaw nodes list`） |
| `--command` | invoke 命令名 |
| `--params` | JSON 字符串参数 |
| `--invoke-timeout` | 超时（毫秒），默认 15000 |

**获取节点 ID**：
```bash
openclaw nodes list
```
