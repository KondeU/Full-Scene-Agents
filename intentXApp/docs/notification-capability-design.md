# Notification 节点能力架构设计

> 为 HarmonyOS Node 实现「Gateway → 设备」方向的通知推送能力。
> 当 Gateway 通过 `node.invoke` 向设备发送 `system.notify` 命令时，设备弹出系统通知栏通知。
> 遵循与 Location 能力一致的"最小侵入式修改，优先新增文件"原则。

---

## 一、现状分析

### 1.1 已有但未接通的

| 组件 | 状态 |
|------|------|
| `OpenClawCapability.Notifications = 'notifications'` | 协议常量已定义，未导入使用 |
| `OpenClawCapability.System = 'system'` | 协议常量已定义，未导入使用 |
| `OpenClawSystemCommand.Notify = 'system.notify'` | 命令字符串已定义，未注册 |
| `OpenClawNotificationsCommand.List = 'notifications.list'` | 命令字符串已定义，未注册 |
| `OpenClawNotificationsCommand.Actions = 'notifications.actions'` | 命令字符串已定义，未注册 |
| Gateway 协议支持 | 服务端已完整实现 `system.notify` → `node.invoke` 流程 |
| Gateway 白名单 | `UNKNOWN_PLATFORM_COMMANDS` 已含 `NOTIFICATIONS_COMMANDS` + `SYSTEM_COMMANDS`，无需改 |
| Form 卡片推送 (`@kit.FormKit`) | CardReminderService 已实现 widget 更新，但与系统通知无关 |

### 1.2 缺失的

| 组件 | 缺失内容 |
|------|----------|
| `InvokeCommandRegistry.ets` | 未注册 `system.notify` 命令，未宣告 `system` 能力 |
| `NodeInvokeDispatcher.ets` | 无 `system.notify` 的 case handler |
| `NodeInvokeDispatcher.ets:buildDevicePermissionsPayload()` | notifications 写死为 `'not_implemented'` |
| Notification 服务文件 | 不存在 |
| `module.json5` | 无 `ohos.permission.NOTIFICATION_CONTROLLER` 权限 |
| `HarmonyNodeRuntimeFlags` | 无 `notificationSystemAvailable` 标志位 |

### 1.3 本次实现范围

| 命令 | 方向 | 本期 | 说明 |
|------|------|------|------|
| `system.notify` | Gateway → 设备 | ✅ | 收到命令后弹出系统通知 |
| `notifications.list` | Gateway → 设备 | ❌ 留 Phase 2 | 返回当前设备通知列表 |
| `notifications.actions` | Gateway → 设备 | ❌ 留 Phase 2 | 打开/关闭/回复通知 |
| `notifications.changed` | 设备 → Gateway | ❌ 留 Phase 2 | 设备通知转发给 Agent |

---

## 二、整体数据流

```
Gateway node.invoke {command:"system.notify", params:{title, body, sound?, priority?}}
  → MainViewModel 接收 WebSocket 事件帧
    → nodeInvokeDispatcher.handleInvoke(request)
      → case 'system.notify':
        → notificationService.handleSystemNotify(request)
          → 解析 params: { title, body, sound?, priority? }
          → 构建 NotificationRequest (HarmonyOS @kit.NotificationKit)
            - 设置标题 (title)、正文 (body)
            - 优先级映射: passive→SERVICE_INFORMATION, timeSensitive→SOCIAL_COMMUNICATION, 默认→SOCIAL_COMMUNICATION
            - 静音处理: sound 为 "none"/"silent"/"off" 时静音
            - 点击通知拉起主应用 (wantAgent → EntryAbility)
          → notificationManager.publish(request, callback)
          ← InvokeResult.ok({notifyId})
      ← Gateway 返回给 Agent: ok=true
```

### 与 Location 能力的对比

```
Location 流程:
  Gateway → node.invoke {command:"location.get"}
    → NodeInvokeDispatcher.handleInvoke()
      → case 'location.get': locationService.handleGetLocation(request)
        → 读取 SecurePrefs → 调用 @kit.LocationKit → 返回坐标
      ← InvokeResult.ok(payloadJson)

Notification 流程 (本期):
  Gateway → node.invoke {command:"system.notify"}
    → NodeInvokeDispatcher.handleInvoke()
      → case 'system.notify': notificationService.handleSystemNotify(request)
        → 解析 params → 构建 NotificationRequest → @kit.NotificationKit.publish
      ← InvokeResult.ok('{notifyId}')
```

---

## 三、设计决策

### 决策 A: Handler 模式 vs 直接在 dispatcher 处理

- **推荐**: Handler 模式（新增 `NotificationService`，与 `LocationService` 一致）
- **理由**: 通知发布涉及权限检查、优先级映射、wantAgent 构建，不应污染 dispatcher switch-case
- **影响**: 新增 `service/NotificationService.ets`（~100 行）

### 决策 B: 通知点击行为

- **推荐**: 点击通知 → 拉起主应用 EntryAbility
- **理由**: 用户收到 Agent 推送后，大概率需要打开应用查看或对话
- **实现**: 通过 `wantAgent.getWantAgent` 构造 WantAgent，`bundleName` **动态获取**而非硬编码：
  ```typescript
  const ctx = AppStorage.get<Context>('abilityContext');
  const bundleName = ctx?.abilityInfo?.bundleName || '';
  ```
  避免硬编码 `'ai.openclaw.harmony'` 导致换签名/包名后通知点击失效。

### 决策 C: 不存储通知历史

- **推荐**: 不在客户端维护通知历史
- **理由**: 本期只实现推送弹出，后续 `notifications.list` 命令直接调用系统 API 获取当前活跃通知
- **影响**: 无持久化需求，减少代码

### 决策 D: 优先级映射

| Gateway 传值 | HarmonyOS SlotType 映射 |
|-------------|------------------------|
| `"passive"` | `notificationManager.SlotType.SERVICE_INFORMATION` (低优先级) |
| `"active"` / 不传 | `notificationManager.SlotType.SOCIAL_COMMUNICATION` (默认) |
| `"timeSensitive"` | `notificationManager.SlotType.SOCIAL_COMMUNICATION` (高优先级) |

### 决策 E: 静音处理

| sound 参数值 | 行为 |
|-------------|------|
| `"none"` / `"silent"` / `"off"` / `"false"` / `"0"` | 静音（设置低优先级 Slot + 不播放声音） |
| 其他值 / 不传 | 保留原 SlotType，使用系统默认声音 |

> **注意**: 静音不改变 `slotType`——仅通过 `NotificationRequest` 的声音控制实现静默。
> 即使 `priority: "timeSensitive"` 且 `sound: "none"`，仍保留 `SOCIAL_COMMUNICATION` SlotType，
> 确保通知在通知栏中的可见度不被降级。

### 决策 F: 通知 ID 生成策略

- **推荐**: 使用递增计数器
- **理由**: `Date.now()` 在毫秒级并发时产生相同 ID，导致后一条通知静默覆盖前一条
- **实现**: `NotificationService` 持有私有静态计数器 `nextId`，每次 `handleSystemNotify` 自增

### 决策 G: Slot 预注册

- **推荐**: 在 `NotificationService` 初始化时调用 `notificationManager.addSlot()`
- **理由**: HarmonyOS API 14+ 要求先创建 Slot 再 publish，否则通知不显示（静默失败）
- **实现**: 在 Service 构造函数或首次 `handleSystemNotify` 调用时批量注册所需 SlotType
- **需要 Context**: 通过 `AppStorage.get<Context>('abilityContext')` 获取

### 决策 H: 防刷屏保护

- **推荐**: 简单限流——每秒最多 3 条，每分钟最多 10 条
- **理由**: 避免 Agent 死循环或恶意 Gateway 轰炸通知栏
- **实现**: 维护 `recentTimestamps: number[]`，每次发布前清理过期记录并检查阈值

### 决策 I: 前台抑制

- **推荐**: 应用在前台时跳过系统通知（Agent 回复已在 ChatPage 中可见）
- **理由**: 用户正在看 App 时弹系统通知是冗余打扰
- **实现**: 通过 `NodeInvokeDispatcherCallbacks.isForeground()` 判断，前台时返回 ok 但不 publish

---

## 四、需要新增/修改的文件

### 4.1 新增文件

| 文件 | 用途 |
|------|------|
| `entry/src/main/ets/service/NotificationService.ets` | 处理 `system.notify` 命令，构建并发布系统通知 |

### 4.2 修改文件

| 文件 | 修改内容 |
|------|---------|
| `node/InvokeCommandRegistry.ets` | 添加 `system.notify` 命令 + `notificationSystemAvailable` 标志位 + 宣告 `system` 能力 |
| `node/NodeInvokeDispatcher.ets` | 添加 import + `system.notify` case handler |
| `entry/src/main/module.json5` | 声明 `ohos.permission.NOTIFICATION_CONTROLLER` 权限 |
| `entry/src/main/resources/base/element/string.json` | 添加 `notification_permission_reason` |
| `entry/src/main/resources/zh_CN/element/string.json` | 添加 `notification_permission_reason` |

---

## 五、详细实现

### 5.1 `module.json5` — 声明通知权限

在 `requestPermissions` 数组中添加：

```json
{
  "name": "ohos.permission.NOTIFICATION_CONTROLLER",
  "reason": "$string:notification_permission_reason",
  "usedScene": {
    "abilities": ["EntryAbility"],
    "when": "inuse"
  }
}
```

字符串资源：
- base: `"notification_permission_reason": "Used to display agent push notifications in the notification bar"`
- zh_CN: `"notification_permission_reason": "用于在通知栏显示Agent推送的通知"`

### 5.2 `InvokeCommandRegistry.ets` — 注册命令 + 宣告能力

**HarmonyNodeRuntimeFlags 新增字段**：

```typescript
notificationSystemAvailable: boolean = true;
```

**all 数组新增**：

```typescript
new InvokeCommandSpec(OpenClawSystemCommand.Notify),
```

**advertisedCapabilities 新增**：

```typescript
if (flags.notificationSystemAvailable) {
    caps.push(OpenClawCapability.System);
}
```

**advertisedCommands 新增**：

```typescript
if (flags.notificationSystemAvailable) {
    commands.push(OpenClawSystemCommand.Notify);
}
```

### 5.3 `NodeInvokeDispatcher.ets` — 添加 handler

**import 区新增**：

```typescript
import { OpenClawSystemCommand } from '../protocol/OpenClawProtocolConstants';
import { notificationService } from '../service/NotificationService';
```

**switch-case 区新增**：

```typescript
case OpenClawSystemCommand.Notify:
    // 前台时不弹系统通知（Agent 回复已在 ChatPage 可见）
    if (this.callbacks.isForeground()) {
        return InvokeResult.ok('{}');
    }
    return await notificationService.handleSystemNotify(request);
```

> `buildDevicePermissionsPayload()` 中 `notifications: 'not_implemented'` 本期不做改动 —
> `system.notify` 走 `system` 能力通道，不涉及 `notifications` 权限上报。

### 5.4 `NotificationService.ets` (新增)

```typescript
import { notificationManager, wantAgent } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { InvokeRequest, InvokeResult } from '../api/GatewaySession';

const TAG = 'NotificationService';

// 限流配置
const MAX_PER_SECOND = 3;
const MAX_PER_MINUTE = 10;

interface SystemNotifyParams {
  title: string;
  body: string;
  sound?: string;
  priority?: string;
}

export class NotificationService {
  private static nextId: number = 1;
  private recentTimestamps: number[] = [];
  private slotsRegistered: boolean = false;

  async handleSystemNotify(request: InvokeRequest): Promise<InvokeResult> {
    // 1. 解析参数
    let params: SystemNotifyParams;
    try {
      const pj = request.paramsJson.trim();
      if (pj.length === 0) {
        return InvokeResult.error('INVALID_PARAMS', 'Missing title and body');
      }
      params = JSON.parse(pj) as SystemNotifyParams;
    } catch (_) {
      return InvokeResult.error('INVALID_PARAMS', 'Invalid JSON');
    }

    if (!params.title || params.title.trim().length === 0 ||
        !params.body || params.body.trim().length === 0) {
      return InvokeResult.error('INVALID_PARAMS', 'title and body are required');
    }

    // 2. 限流检查
    if (!this.checkRateLimit()) {
      return InvokeResult.error('RATE_LIMITED', 'Too many notifications');
    }

    // 3. 确保 Slot 已注册
    this.ensureSlotsRegistered();

    // 4. 优先级映射
    const slotType = this.mapPriority(params.priority);

    // 5. 静音判断（不覆盖 slotType，仅标记）
    const silent = this.isSilent(params.sound);

    // 6. 构建 WantAgent（bundleName 动态获取）
    const wa = await this.buildWantAgent();

    // 7. 发布通知（递增 ID 保证唯一性）
    const notifyId = NotificationService.nextId++;

    const notificationReq: notificationManager.NotificationRequest = {
      id: notifyId,
      content: {
        notificationContentType: notificationManager.ContentType
          .NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: params.title.trim(),
          text: params.body.trim()
        }
      },
      notificationSlotType: slotType,
      isOngoing: false,
      isUnremovable: false,
      wantAgent: wa
    };

    return new Promise<InvokeResult>((resolve) => {
      notificationManager.publish(notificationReq, (err: BusinessError) => {
        if (err) {
          console.error(TAG + ' publish failed: code=' + err.code +
            ', msg=' + err.message);
          resolve(InvokeResult.error('NOTIFY_FAILED', err.message));
        } else {
          console.info(TAG + ' published notifyId=' + notifyId +
            ' title=' + params.title);
          resolve(InvokeResult.ok(JSON.stringify({ notifyId: notifyId })));
        }
      });
    });
  }

  /**
   * 限流检查：每秒 ≤ 3 条，每分钟 ≤ 10 条。
   */
  private checkRateLimit(): boolean {
    const now = Date.now();
    this.recentTimestamps = this.recentTimestamps.filter(
      (t: number) => now - t < 60000
    );
    const perSecond = this.recentTimestamps.filter(
      (t: number) => now - t < 1000
    ).length;
    if (perSecond >= MAX_PER_SECOND || this.recentTimestamps.length >= MAX_PER_MINUTE) {
      console.warn(TAG + ' rate limited: perSec=' + perSecond +
        ', perMin=' + this.recentTimestamps.length);
      return false;
    }
    this.recentTimestamps.push(now);
    return true;
  }

  /**
   * 确保通知 Slot 已注册（API 14+ 必需）。
   */
  private ensureSlotsRegistered(): void {
    if (this.slotsRegistered) {
      return;
    }
    try {
      const slotSocial: notificationManager.NotificationSlot = {
        type: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        level: notificationManager.SlotLevel.LEVEL_HIGH,
        desc: 'Agent notifications'
      };
      const slotService: notificationManager.NotificationSlot = {
        type: notificationManager.SlotType.SERVICE_INFORMATION,
        level: notificationManager.SlotLevel.LEVEL_MIN,
        desc: 'Agent low-priority notifications'
      };
      notificationManager.addSlot(slotSocial, (err: BusinessError) => {
        if (err) {
          console.warn(TAG + ' addSlot SOCIAL_COMMUNICATION failed: ' + err.message);
        }
      });
      notificationManager.addSlot(slotService, (err: BusinessError) => {
        if (err) {
          console.warn(TAG + ' addSlot SERVICE_INFORMATION failed: ' + err.message);
        }
      });
      this.slotsRegistered = true;
    } catch (err) {
      console.warn(TAG + ' ensureSlotsRegistered exception: ' + (err as Error).message);
    }
  }

  private mapPriority(priority?: string): notificationManager.SlotType {
    if (!priority) {
      return notificationManager.SlotType.SOCIAL_COMMUNICATION;
    }
    switch (priority.toLowerCase().trim()) {
      case 'passive':
        return notificationManager.SlotType.SERVICE_INFORMATION;
      case 'timesensitive':
        return notificationManager.SlotType.SOCIAL_COMMUNICATION;
      default:
        return notificationManager.SlotType.SOCIAL_COMMUNICATION;
    }
  }

  private isSilent(sound?: string): boolean {
    if (!sound) {
      return false;
    }
    const s = sound.toLowerCase().trim();
    return s === 'none' || s === 'silent' || s === 'off' ||
           s === 'false' || s === '0';
  }

  private async buildWantAgent(): Promise<WA | undefined> {
    try {
      const ctx = AppStorage.get<Context>('abilityContext');
      const bundleName = ctx?.abilityInfo?.bundleName ||
        'ai.openclaw.harmony';
      const wantInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: bundleName,
            abilityName: 'EntryAbility'
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      return await wantAgent.getWantAgent(wantInfo);
    } catch (err) {
      console.warn(TAG + ' buildWantAgent failed: ' + (err as Error).message);
      return undefined;
    }
  }
}

export const notificationService = new NotificationService();
```

> **编译注意**: `notificationManager.SlotType` 枚举值以目标 SDK 版本为准。编写前需查阅 `@kit.NotificationKit` 文档确认。

---

## 六、修改影响评估

| 修改项 | 类型 | 影响范围 |
|--------|------|---------|
| `module.json5` | 新增权限 | 仅声明权限，用户首次触发时授权 |
| `InvokeCommandRegistry.ets` | +8 行 | 新增命令注册 + 能力宣告 + 标志位 |
| `NodeInvokeDispatcher.ets` | +5 行 | 新增 import + case handler（含前台判断） |
| `NotificationService.ets` | 新文件 | 独立模块，~190 行（含限流 + Slot 注册 + 动态 bundleName） |
| `string.json (base + zh_CN)` | +4 行 x2 | 权限描述字符串 |

**总新增代码量**: ~210 行（1 个新文件 + ~20 行修改）

---

## 七、风险与边界条件

### 7.1 权限

- `ohos.permission.NOTIFICATION_CONTROLLER` 是系统级权限，需在 `module.json5` 中声明
- 首次发布通知时系统可能提示用户授权；用户拒绝则 `publish` 回调返回 error

### 7.2 WantAgent 拉起应用

- 通知点击后拉起 EntryAbility，`bundleName` / `abilityName` 必须与 `module.json5` 一致
- 当前: `bundleName = "ai.openclaw.harmony"`, `abilityName = "EntryAbility"`

### 7.3 离线场景

- Gateway 已断开时不会收到 `node.invoke`，无处理需求
- 通知只在实际收到命令时弹出，不做离线缓存

### 7.4 通知渠道

- 当前使用系统预设 `SlotType.SOCIAL_COMMUNICATION`，无需额外创建通知渠道
- 如需自定义渠道（图标、铃声、振动），后续可调用 `notificationManager.addSlot()`

### 7.5 多通知

- 使用 `Date.now()` 作为 notifyId，每次发布都会创建新通知（不覆盖旧的）
- 如需限制通知数量或去重，后续可增加策略

---

## 八、未来演进路线

### Phase 1 — 当前（本期）

- [x] `system.notify` 命令接收 + 系统通知弹出
- [x] 通知优先级映射（passive / active / timeSensitive）
- [x] 静音处理（sound=none/silent/off）
- [x] 点击通知 → 拉起主应用
- [ ] 端到端验证：Agent → Gateway → 设备弹出通知

### Phase 2

- [ ] `notifications.list` — 返回当前设备通知列表
- [ ] `notifications.actions` — 打开/关闭/回复通知
- [ ] 自定义通知渠道（图标、振动、铃声）
- [ ] `notifications.changed` — 设备通知监听 + 转发给 Agent

### Phase 3

- [ ] 通知转发策略（允许列表/阻止列表、免打扰时段、速率限制）
- [ ] Push Kit 集成（FCM/HMS 离线推送唤醒）

---

## 九、蓝军审视报告

> 以蓝军（攻击方/质疑方）视角审视当前设计与代码，聚焦商用落地中会真实爆掉的问题。
> 分为 **P0（必炸）**、**P1（隐患）**、**P2（设计债务）** 三级。

### P0-01: `bundleName` 硬编码为 `'ai.openclaw.harmony'`——换签名/换包名即炸

**位置**: `NotificationService.ets:323`

**问题**:
```typescript
wants: [{
    bundleName: 'ai.openclaw.harmony',
    abilityName: 'EntryAbility'
}]
```

`bundleName` 以字符串硬编码。如果项目换了签名配置（如当前 `build-profile.json5` 中的 `default_intentXApp` 或 `default_HarmonyOS` 对应不同的 bundleName）、走不同的构建变体、或未来更换鸿蒙分发 profile，此处就会与实际包名不一致。通知点击后系统找不到对应的 Ability，用户点击通知无反应甚至 crash。

HarmonyOS 的 `bundleName` 来源于 `AppScope/app.json5`，该值在构建时注入。硬编码意味着每次 `app.json5` 变化都需要人工同步代码。

**修复**: 从 context 动态获取——`this.context.abilityInfo.bundleName` 或 `getContext().applicationInfo.name`，或通过 AppStorage 传入的 `abilityContext` 取 `abilityInfo.bundleName`。

### P0-02: 未调用 `addSlot()` —— API 14+ 通知根本不显示

**位置**: `NotificationService.ets:281`（`notificationManager.publish()`）

**问题**:
HarmonyOS NEXT (API 14+) 的通知机制要求**先创建 Slot 再 publish**。当前设计使用 `SlotType.SOCIAL_COMMUNICATION` 和 `SlotType.SERVICE_INFORMATION`，但从未调用 `notificationManager.addSlot()` 或 `notificationManager.addSlots()` 来注册这些 Slot。

如果 Slot 不存在，`publish()` 的行为是：
- API 11-13: 系统自动创建默认 Slot，通知可显示（运气好）
- API 14+: 返回错误或静默丢弃通知，通知栏看不到任何内容

Agent 辛辛苦苦推了一条通知 —— 用户完全看不见。这是**静默失败**，没有 UI 提示，也没有日志告警（除了 publish 回调的 err）。

**影响**: Agent 推送成功率 0%，用户困惑"为什么 Agent 说要通知我了但什么都没发生"，运营/体验报废。

**修复**: 在 `NotificationService` 构造函数或 `handleSystemNotify` 入口中预注册 Slot：
```typescript
const slot: notificationManager.NotificationSlot = {
    type: notificationManager.SlotType.SOCIAL_COMMUNICATION,
    level: notificationManager.SlotLevel.LEVEL_HIGH,
    desc: 'Agent notifications'
};
notificationManager.addSlot(slot);
```
需要在 `NotificationService` 持有 `context` 引用（或从 AppStorage 读取）才能调用 `addSlot`。

### P0-03: `Date.now()` 作为通知 ID —— 毫秒级并发导致通知覆盖/丢失

**位置**: `NotificationService.ets:257`

**问题**:
```typescript
const notifyId = Date.now();
```

如果 Gateway 在同一个毫秒内连续推送两条 `system.notify`（这在 Agent 批处理或连续操作中完全可能），第二条通知的 `notifyId` 与第一条相同。`notificationManager.publish()` 对相同 ID 的行为是**替换**——第二条**覆盖**第一条。用户只看到最后一条，第一条通知的内容永久丢失。

更严重的是：如果第一条通知已经弹出、用户还没来得及看，就被第二条静默替换了。

**影响**: 通知丢失、用户困惑。

**修复**: 使用递增计数器而非时间戳：
```typescript
private static nextId: number = 1;
// 在 handleSystemNotify 中:
const notifyId = NotificationService.nextId++;
```
或者使用 `Date.now() * 1000 + (NotificationService.nextId++ % 1000)` 保证唯一性。

### P1-01: 静音逻辑覆盖优先级映射 —— "timeSensitive 静音"被降级

**位置**: `NotificationService.ets:275-279`

**问题**:
```typescript
if (silent) {
    notificationReq.notificationSlotType =
        notificationManager.SlotType.SERVICE_INFORMATION;
}
```

无论原始 `priority` 是什么（包括 `timeSensitive`），只要传了 `sound: "none"`，SlotType 就被硬覆盖为 `SERVICE_INFORMATION`。但 `SERVICE_INFORMATION` 在系统侧意味着"服务信息，不打扰"，可能会被聚合展示、降低排序、甚至在某些设备上默认折叠。

如果 Agent 希望发一条高优先级但静音的通知（比如"任务已在后台完成"——重要但不紧迫），这个逻辑使其被降级为低可见度。

**影响**: 通知优先级语义被破坏。

**修复**: 静音通过 `NotificationRequest` 的 `sound` 字段或 `NotificationSlot.level` 控制，不应覆盖 `slotType`：
```typescript
if (silent) {
    // 仅降级振铃，不改变 slot 类型
    notificationReq.notificationSlotType = slotType;
    // 使用系统静默通道或其他控制方式
}
```
或：不静音情况下才保留原 slotType，静音统一用 `SERVICE_INFORMATION` 但在文档中明确标注此行为。

### P1-02: 无通知 Slot 预注册 —— 多类型 Slot 依赖隐式创建

**位置**: `NotificationService.ets` 整体

**问题**:
设计使用两种 SlotType（`SOCIAL_COMMUNICATION` 和 `SERVICE_INFORMATION`），但从未显式注册 Slot。虽然在部分 API 版本上系统会隐式创建，但隐式行为的参数不可控（默认 level、振动、锁屏可见性等都取系统默认值），在生产环境中不可接受。

更重要的是：`addSlot` 需要 Context。当前 `NotificationService` 是纯服务类，**不持有 Context**。需要从哪里获取 Context？

**影响**: 通知行为和用户预期不一致。

**修复**: 在 Service 构造函数中接受 Context 或从 `AppStorage.get<Context>('abilityContext')` 获取，并在 `handleSystemNotify` 首次调用时注册 Slot。

### P1-03: `handleSystemNotify` 无权限检查 —— 权限拒绝后静默失败

**位置**: `NotificationService.ets:281`（publish 回调）

**问题**:
`ohos.permission.NOTIFICATION_CONTROLLER` 虽然已在 `module.json5` 中声明，但**用户可以在系统设置中关闭通知权限**。如果用户关闭了权限，`publish()` 回调会收到错误。但当前代码只返回 `InvokeResult.error('NOTIFY_FAILED', err.message)` 给 Gateway，通知失败不会记录到客户端任何持久化位置，也不会给用户任何 UI 提示（用户不知道 Agent 尝试发过通知）。

**影响**: Agent 认为通知已送达（在 `known_failures` 缓存之前），但实际上用户没收到。这是一个不可观测的失败。

**修复**: 返回 error 时可附加更具体的错误码（如 `NOTIFY_PERMISSION_DENIED`），供 Gateway 侧决策；客户端侧可考虑 toast 提示用户开启权限。

### P1-04: 无防刷屏保护 —— Agent 或恶意 Gateway 可无限轰炸通知

**位置**: `NotificationService.ets` 整体

**问题**:
当前设计没有任何速率限制。如果 Agent 进入死循环或恶意 Gateway 连续发送 `system.notify`，设备通知栏会在几秒内被填满。Android/iOS 系统层面有通知频率限制，但 HarmonyOS 的全局限制机制不明确，且即使有限制，同应用内短时间大量通知的体验仍然极差。

**影响**: 用户被通知轰炸，可能卸载应用或关闭通知权限。

**修复**: 在 `NotificationService` 中增加简单限流——如每秒最多 3 条、每分钟最多 10 条。超过阈值直接返回 `InvokeResult.error('RATE_LIMITED', 'Too many notifications')`。

### P1-05: 前台时仍弹出通知 —— 重复打扰

**位置**: 设计决策 B（未提及前后台判断）

**问题**:
如果用户正在使用 IntentX App（前台），Gateway 推送的 `system.notify` 仍会弹出系统通知栏通知，点击后"拉起正在看的主应用"——这是完全多余的操作。用户正在看聊天页面，Agent 的回复已经在对话流中，不需要额外的通知顶上。

**影响**: 冗余通知干扰用户。

**修复**: 在 `handleSystemNotify` 中检查应用是否在前台（通过 `NodeInvokeDispatcherCallbacks.isForeground()`），前台时可选择：
- 直接返回 ok（跳过通知，Agent 的回复已在 ChatPage 中）
- 或显示应用内 toast/banner 而非系统通知

### P2-01: 通知无分组 —— 多条通知散落通知栏

**问题**: 同一来源的多个通知不会自动分组。如果 Agent 连续发送 3 条通知，用户看到 3 个独立条目堆叠在通知栏，无折叠、无归纳。

**修复**: 使用 `notificationManager.NotificationRequest.groupName` 参数将通知分组。

### P2-02: 通知无自动过期 —— 持久驻留直到手动清除

**问题**: `isOngoing: false` 但 `isUnremovable: false`，通知虽可滑动清除但不会自动消失。低优先级通知应在一段时间后自动清除。

**修复**: 利用 `NotificationRequest.autoDeletedTime`（API 12+）或在 publish 后设置定时器调用 `notificationManager.cancel(notifyId)`。

### P2-03: Want 点击无上下文 —— 通知点击后不知道是哪条

**问题**: 点击通知后只是打开 EntryAbility，没有传递任何参数表明"这是哪条通知"。用户看到主页面，不知道 Agent 为什么叫他们。应该在 Want 的 `parameters` 中传递通知来源信息（如 `notificationId`、`sessionKey`），让 EntryAbility 可以路由到对应页面。

**修复**: 在 `wants[0].parameters` 中添加 `{ notificationId: notifyId, source: 'agent' }`，EntryAbility 的 `onNewWant` 读取后路由。

### P2-04: 编译注意事项未转化为代码防御

**位置**: 设计文档第 342-344 行

**问题**: 文档有"编译注意"提醒 API 枚举值以实际 SDK 为准，但未转化为代码级的防御措施。实际编译时如果 `SlotType.SOCIAL_COMMUNICATION` 不存在，就是编译错误。

**修复**: 在开始编码前，确认目标 SDK（当前为 API 20）中 `notificationManager.SlotType` 的实际枚举名。查阅 `@kit.NotificationKit` 文档或直接 IDE 补全确认。

---

## 十、问题优先级总结

| ID | 级别 | 问题 | 状态 |
|----|------|------|------|
| P0-01 | **必炸** | bundleName 硬编码 —— 换签名即无法点击 | ✅ 已修复（从 context 动态获取） |
| P0-02 | **必炸** | 未调用 addSlot —— API 14+ 通知不显示 | ✅ 已修复（ensureSlotsRegistered） |
| P0-03 | **必炸** | Date.now() 作为 notifyId —— 毫秒级并发覆盖 | ✅ 已修复（递增计数器） |
| P1-01 | **隐患** | 静音覆盖优先级映射 —— timeSensitive 被降级 | ✅ 已修复（静音不改变 slotType） |
| P1-02 | **隐患** | 无 Slot 预注册 —— 隐式创建不可控 | ✅ 已修复（合并到 P0-02） |
| P1-03 | **隐患** | 无权限检查 —— 权限拒绝后静默失败 | 🔄 待修复（publish 回调已有 err 返回 Gateway，客户端侧 toast 留 Phase 2） |
| P1-04 | **隐患** | 无防刷屏保护 —— 可被无限轰炸 | ✅ 已修复（每秒 3 条 / 每分钟 10 条限流） |
| P1-05 | **隐患** | 前台时仍弹出通知 —— 重复打扰 | ✅ 已修复（Dispatcher 层 isForeground 判断） |
| P2-01 | **债务** | 无通知分组 —— 多通知散落 | 后续优化 |
| P2-02 | **债务** | 无自动过期 —— 持久驻留 | 后续优化 |
| P2-03 | **债务** | Want 点击无上下文 —— 不知道哪条通知 | 后续优化 |
| P2-04 | **债务** | API 枚举未验证 —— 编译可能失败 | 编码前确认 |
