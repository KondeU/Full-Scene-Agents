# HarmonyOS Node 能力调用指南

> 面向 OpenClaw Agent：本指南描述 HarmonyOS 设备 Node 暴露给智能体的 Tool 能力。所有命令可直接复制使用。

---

## 快速参考

| 能力 | Command | 用途 |
|------|---------|------|
| 推送桌面卡片 | `card.reminder.update` | 向设备桌面 2×4 服务卡片推送内容 |
| 获取设备位置 | `location.get` | 获取设备当前地理位置 |
| 发送通知 | `system.notify` | 向系统通知栏推送通知 |

> `--node <id>` 通过 `openclaw nodes list` 获取。

---

## 一、推送桌面卡片 (`card.reminder.update`)

### 1.1 信息展示卡（默认风格）

左文字右缩略图布局。`style` 不传时默认使用此风格。

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params "{\"title\":\"会议提醒\",\"body\":\"下午3:00 产品评审，A304\",\"note\":\"请准备演示材料\"}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `body` | **是** | 正文，卡片核心文字 |
| `title` | 否 | 标题行，浅色小字 |
| `note` | 否 | 备注行，浅色小字 |
| `imageUrl` | 否 | 右侧缩略图 URL（132×120vp） |
| `skill` | 否 | 拍照/选图后发给 chat 的技能指令，见 1.3 节 |

### 1.2 图片导入卡 (`infoShowTitleImageAndImport`)

全幅背景图 + 右侧两个半透明按钮（"拍一拍"/"选一选"），引导用户拍照或选图导入。

**有背景图：**

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"今日健康推荐\",\"imageUrl\":\"https://example.com/meal.jpg\"}"
```

**无背景图（纯文字+按钮）：**

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"拍一张今天的午餐吧\"}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `body` | **是** | 正文，卡片左上角文字 |
| `imageUrl` | 否 | 背景图 URL。有图时全幅铺满，无图时白底 |
| `title` | — | 此风格下忽略 |
| `note` | — | 此风格下忽略 |
| `skill` | 否 | 拍照/选图后发给 chat 的技能指令，见 1.3 节 |

**按钮行为**：
- **"拍一拍"**：拉起 App 到导入页，自动打开相机拍照
- **"选一选"**：拉起 App 到导入页，自动打开相册选取

### 1.3 `skill` 参数（图片导入后的文本指令）

`skill` 不参与卡片渲染。用户通过卡片按钮拍照/选图后，skill 决定发送给 chat 的消息文本。

| skill 值 | 发送给 chat 的文本 |
|----------|-------------------|
| 空 / 不传 | `/ImageData` |
| `"数据录入"` | `/skill 数据录入` |
| `"健康记录"` | `/skill 健康记录` |

**无背景图 + skill：**

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"拍体检报告\",\"skill\":\"数据录入\"}"
```

**有背景图 + skill：**

```bash
openclaw nodes invoke --node <id> --command card.reminder.update --params "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"今日健康推荐\",\"imageUrl\":\"https://example.com/meal.jpg\",\"skill\":\"数据录入\"}"
```

### 1.4 交互流程

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

### 2.1 调用方式

```bash
openclaw nodes invoke --node <id> --command location.get --params "{\"desiredAccuracy\":\"precise\",\"timeoutMs\":10000}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `desiredAccuracy` | 否 | `"precise"`（默认，高精度）、`"balanced"`（均衡）、`"coarse"`（低功耗） |
| `timeoutMs` | 否 | 定位超时（毫秒），默认 10000 |

### 2.2 返回结构

```json
{
  "latitude": 31.2304,
  "longitude": 121.4737,
  "altitude": 4.5,
  "accuracy": 15.0,
  "timestamp": 1718000000000
}
```

### 2.3 隐私控制

- 用户可在设置中关闭定位或切换为粗略精度
- 关闭时返回错误 `LOCATION_DISABLED`
- 粗略精度时自动使用 `balanced` 模式

---

## 三、发送通知 (`system.notify`)

### 3.1 调用方式

```bash
openclaw nodes invoke --node <id> --command system.notify --params "{\"title\":\"Agent 通知\",\"body\":\"您的任务已完成\"}"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `title` | **是** | 通知标题 |
| `body` | **是** | 通知正文 |
| `priority` | 否 | `"active"`（默认）、`"passive"`（低优先级）、`"timeSensitive"`（时效性） |
| `sound` | 否 | 空=系统默认声音，`"none"`=静音 |

### 3.2 行为说明

- 应用在前台时**不弹出系统通知**（Agent 回复已在聊天页面可见），返回 ok 但跳过 publish
- 通知点击后自动拉起 App
- 通知 ID 使用自增计数器，避免并发冲突

---

## 附：`openclaw nodes invoke` 通用格式

```bash
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
