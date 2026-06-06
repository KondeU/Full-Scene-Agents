# Location 节点能力架构设计

> 为 HarmonyOS Node 新增 `location.get` 命令，使 Gateway 能获取设备当前位置。
> 遵循"最小侵入式修改，优先新增文件"原则。

---

## 一、现状分析

### 1.1 已有但未接通的

| 组件 | 状态 |
|------|------|
| `OpenClawCapability.Location = 'location'` | 协议常量已定义，未导入使用 |
| `OpenClawLocationCommand.Get = 'location.get'` | 命令字符串已定义，未注册 |
| UI 位置偏好 | SettingsPage / OnboardingPage 有 Off/Approx/Precise 控件，写入 SecurePrefs |
| `SecurePrefs.LocationMode` 枚举 | `Off / Approximate / Precise` 已存在 |
| Gateway 白名单 | `UNKNOWN_PLATFORM_COMMANDS` 已含 `LOCATION_COMMANDS`，无需改 |
| Gateway Agent 工具 | `nodes-tool.ts` 已有 `location_get` 专属 action + 类型化参数 |

### 1.2 缺失的

| 组件 | 缺失内容 |
|------|----------|
| `InvokeCommandRegistry.ets` | 未注册 `location.get` 命令，未宣告 `location` 能力 |
| `NodeInvokeDispatcher.ets` | 无 `location.get` 的 case handler |
| Location 服务文件 | 不存在 |
| `module.json5` | 无 `ohos.permission.LOCATION` / `ohos.permission.APPROXIMATELY_LOCATION` |

---

## 二、整体数据流

```
Gateway node.invoke {command:"location.get", params:{desiredAccuracy,maxAgeMs,timeoutMs}}
  → NodeInvokeDispatcher.handleInvoke()
    → case 'location.get':
      → locationService.getCurrentLocation(params)
        → 读取 SecurePrefs LocationMode（复用现有用户偏好）
        → 调用 @kit.LocationKit geoLocationManager.getCurrentLocation()
        → 返回 {latitude, longitude, altitude, accuracy, timestamp}
      ← InvokeResult.ok(payloadJson)
  ← Gateway 返回给 Agent
```

---

## 三、新增文件

### `service/LocationService.ets`

单一职责：封装定位逻辑，不依赖 MainViewModel。

```
LocationService
  ├─ handleGetLocation(request) → Promise<InvokeResult>
  │   1. 读取 SecurePrefs.getLocationMode()
  │   2. Off → 返回 error "Location disabled by user preference"
  │   3. 解析 desiredAccuracy 参数映射到 LocationKit 策略（API 20 仅两档）：
  │      coarse / balanced → PRIORITY_LOCATING_SPEED（多技术融合，快速响应，精度适中）
  │      precise / 不指定 → PRIORITY_ACCURACY（默认，GNSS，最佳精度）
  │   4. 用户偏好覆盖：Approximate → 强制 PRIORITY_LOCATING_SPEED
  │   5. 调 geoLocationManager.getCurrentLocation()
  │   6. 返回 LocationResult → InvokeResult.ok(json)
```

只依赖：
- `@kit.LocationKit` — `geoLocationManager`
- `../common/SecurePrefs` — 读取位置偏好
- `../api/GatewaySession` — `InvokeRequest`, `InvokeResult`

### `desiredAccuracy` 参数映射

Agent 工具中 `LOCATION_ACCURACY = ["coarse", "balanced", "precise"]`，经 Gateway `location_get` handler 透传到 Node 的 `desiredAccuracy` 字段：

| Agent 取值 | LocationKit 策略 | 说明 |
|------|------|------|
| `"coarse"` / `"balanced"` | `PRIORITY_LOCATING_SPEED` | 多技术融合（GNSS + 基站 + WLAN + 蓝牙），快速响应，室内外可用 |
| `"precise"` 或不指定 | `PRIORITY_ACCURACY` | **默认**，仅 GNSS 定位，米级精度，开阔场景最佳 |

> NOTE: HarmonyOS NEXT API 20 的 `LocatingPriority` 枚举只有 `PRIORITY_ACCURACY` 和 `PRIORITY_LOCATING_SPEED` 两个值。旧版 `PRIORITY_LOW_POWER` 已移除。`coarse` 和 `balanced` 均映射到 `PRIORITY_LOCATING_SPEED`。

**优先级**：Agent 参数 → 被用户偏好覆盖。Settings 中选 `Approximate` 时强制 `PRIORITY_LOCATING_SPEED`，选 `Off` 时直接拒绝。

---

## 四、最小修改已有文件

| 文件 | 改动 | 预计行数 |
|------|------|----------|
| `InvokeCommandRegistry.ets` | import `OpenClawLocationCommand`；`all` 数组 +1；`advertisedCapabilities` +1；`advertisedCommands` +1 | ~4 行 |
| `NodeInvokeDispatcher.ets` | import `locationService`；switch 内 +1 case | ~2 行 |
| `module.json5` | `requestPermissions` 新增 2 个权限声明 | ~14 行 |

**不改动**：MainViewModel、SecurePrefs、SettingsPage、OnboardingPage、EntryAbility — 这些文件中位置偏好已完整，直接复用。

---

## 五、Gateway 侧

无需改动。
- `node-command-policy.ts`：`UNKNOWN_PLATFORM_COMMANDS` 已包含 `LOCATION_COMMANDS`
- `nodes-tool.ts`：已有 `location_get` action + `maxAgeMs`/`desiredAccuracy`/`locationTimeoutMs` 参数

---

## 六、与 card.reminder.update 的对齐

| 环节 | card.reminder.update | location.get |
|------|---------------------|--------------|
| 协议常量 | `OpenClawCardCommand.ReminderUpdate`（新增） | `OpenClawLocationCommand.Get`（已有） |
| 能力常量 | `OpenClawCapability.Card`（新增） | `OpenClawCapability.Location`（已有） |
| 注册表 | `InvokeCommandRegistry.all` + `advertised*` | 同模式，+3 行 |
| 分发器 | `NodeInvokeDispatcher` switch case | 同模式，+1 case |
| 服务文件 | `CardReminderService.ets`（新文件） | `LocationService.ets`（新文件） |
| Gateway 白名单 | `CARD_COMMANDS`（新增） | 已有 `LOCATION_COMMANDS` |
| Gateway 工具 | `card_reminder_update` action（新增） | 已有 `location_get` action |
| 系统权限 | 无 | APPROXIMATELY_LOCATION + LOCATION |

---

## 七、权限配置

### module.json5 新增

```json
{
  "name": "ohos.permission.APPROXIMATELY_LOCATION",
  "reason": "$string:approximate_location_permission_reason",
  "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
},
{
  "name": "ohos.permission.LOCATION",
  "reason": "$string:location_permission_reason",
  "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
}
```

> NOTE: HarmonyOS NEXT 要求 `APPROXIMATELY_LOCATION` 和 `LOCATION` 必须同时声明。已有的 `approximate_location_permission_reason` 和 `location_permission_reason` 字符串资源已存在于 `string.json` 中，无需新增。

---

## 八、用户偏好流（复用现有）

```
用户操作 SettingsPage / OnboardingPage
  → 选择 Off / Approximate / Precise
  → MainViewModel.setLocationMode(mode)
    → SecurePrefs.setLocationMode(mode)
      → 持久化到 preferences

Agent 调用 location.get 时
  → LocationService.desiredAccuracy 参数（coarse/balanced/precise）→ 映射 LocationKit 策略
  → 用户偏好覆盖：
      → Off → 拒绝
      → Approximate → 强制 PRIORITY_LOCATING_SPEED
      → Precise → 以 Agent 参数为准
```

---

## 九、代码结构

### 新增

```
service/
  LocationService.ets       ← 定位服务
```

### 修改

```
node/
  InvokeCommandRegistry.ets ← +4 行
  NodeInvokeDispatcher.ets   ← +2 行
entry/src/main/
  module.json5               ← +2 个 permission 声明
```
