# OpenClaw HarmonyOS Tab 框架深度分析

> 本文档基于实际源码的逐文件梳理，为后续新增 Tab 页面提供完整的架构理解。

---

## 一、整体架构概览

OpenClaw HarmonyOS 应用采用 **MVVM + 条件渲染 Tab** 架构，而非 HarmonyOS 原生的 `Tabs` + `TabContent` 容器。核心设计思路：

- **单一入口页面** (`Index.ets`) 根据引导状态路由到 `OnboardingPage` 或 `PostOnboardingTabs`
- **PostOnboardingTabs** 是五 Tab 的宿主组件，通过 `activeTab` 状态变量 + `if/else` 条件渲染来切换页面内容
- **所有 Tab 页面共享同一个 ViewModel** (`MainViewModel`)，通过 `@ObjectLink` 注入
- **状态驱动 UI**：ViewModel 是 `@Observed` 类，属性变更自动触发 UI 重建
- **监听器模式**：各 Page 通过 `addXxxListener / removeXxxListener` 注册回调来同步 ViewModel 状态到本地 `@State`

```
应用启动流程：

EntryAbility.ets
  → AppStorage 初始化 (abilityContext, localeVersion)
  → SecurePrefs 初始化
  → 加载 pages/Index

Index.ets
  → await MainViewModel.waitUntilReady()
  → if (!onboardingCompleted) → OnboardingPage (4步引导)
  → else → PostOnboardingTabs (5 Tab主界面)

PostOnboardingTabs.ets
  → StatusBar (顶部标题 + 连接状态指示)
  → 条件渲染区域 (activeTab === 0/1/2/3/4)
    → ConnectPage / ChatPage / VoicePage / ScreenPage / SettingsPage
  → TabBar (底部5个Tab按钮)
```

---

## 二、文件分布与职责

### 2.1 入口与路由层

| 文件 | 路径 | 行数 | 职责 |
|------|------|------|------|
| `EntryAbility.ets` | `entryability/` | 96 | UIAbility 生命周期，初始化 AppStorage、SecurePrefs，加载 Index 页面，前台时刷新国际化状态 |
| `Index.ets` | `pages/` | 69 | @Entry 页面，路由逻辑：等待 ViewModel ready → 根据 `onboardingCompleted` 决定显示引导页或主 Tab 页 |

### 2.2 Tab 宿主组件

| 文件 | 路径 | 行数 | 职责 |
|------|------|------|------|
| `PostOnboardingTabs.ets` | `pages/` | 242 | **核心架构组件**。管理 `activeTab` 状态、StatusBar、TabBar、条件渲染5个页面、连接状态监听、Tab 切换副作用 |

**关键设计点**：

```typescript
// PostOnboardingTabs.ets:12-19
@Component
export struct PostOnboardingTabs {
  @ObjectLink viewModel: MainViewModel;       // 共享 ViewModel
  @StorageProp('localeVersion') localeVersion: number = 0;  // 国际化触发器
  @State activeTab: number = 0;               // 当前选中 Tab 索引
  @State connectedState: boolean = false;     // 本地同步的连接状态
  @State statusState: string = '';            // 本地同步的状态文本
  @State screenTabPrimed: boolean = false;    // Screen Tab 是否已首次激活
```

**Tab 切换副作用处理** (`syncTabSideEffects`)：

```typescript
// PostOnboardingTabs.ets:38-44
private syncTabSideEffects(): void {
  void this.viewModel.setVoiceScreenActive(this.activeTab === 2);  // Voice Tab激活时标记
  if (this.activeTab === 3 && !this.screenTabPrimed) {
    this.screenTabPrimed = true;
    this.viewModel.refreshHomeCanvasOverviewIfConnected();  // 首次进入Screen Tab刷新Canvas
  }
}
```

**条件渲染模式**（非 Tabs 容器）：

```typescript
// PostOnboardingTabs.ets:51-61
if (this.activeTab === 0) {
  ConnectPage({ viewModel: this.viewModel });
} else if (this.activeTab === 1) {
  ChatPage({ viewModel: this.viewModel });
} else if (this.activeTab === 2) {
  VoicePage({ viewModel: this.viewModel });
} else if (this.activeTab === 3) {
  ScreenPage({ viewModel: this.viewModel });
} else {
  SettingsPage({ viewModel: this.viewModel });
}
```

**TabBar 实现**：

```typescript
// PostOnboardingTabs.ets:106-149
@Builder TabBar() {
  Row() {
    this.TabItem(0, localizedText('tab_connect', 'Connect'), '🔗');
    this.TabItem(1, localizedText('tab_chat', 'Chat'), '💬');
    this.TabItem(2, localizedText('tab_voice', 'Voice'), '🎙️');
    this.TabItem(3, localizedText('tab_screen', 'Screen'), '🖥️');
    this.TabItem(4, localizedText('tab_settings', 'Settings'), '⚙️');
  }
  // 圆角顶部、边框、白色背景
}

@Builder TabItem(index, label, icon) {
  Column() {
    Text(icon).fontSize(20);
    Text(label).fontSize(11)...  // 选中态蓝色粗体，非选中态灰色
  }
  .layoutWeight(1).height(58)
  .backgroundColor(activeTab === index ? '#ECF3FF' : 'transparent')
  .borderRadius(16)
  .onClick(() => { this.activeTab = index; this.syncTabSideEffects(); });
}
```

### 2.3 五个 Tab 页面

| Tab 索引 | 名称 | 文件 | 行数 | 装饰器 | 核心职责 |
|----------|------|------|------|--------|----------|
| 0 | 连接 | `ConnectPage.ets` | 670 | `@Component` | 连接管理：SetupCode/Manual双模式、高级设置折叠、端点预览、连接/断开/重连操作 |
| 1 | 聊天 | `ChatPage.ets` | 752 | `@Component` | 聊天界面：消息列表(Markdown渲染)、流式消息、工具调用指示、会话切换、Thinking等级、发送/中止 |
| 2 | 语音 | `VoicePage.ets` | 380 | `@Component` | 语音状态面板：状态码(ready/busy/disabled/unavailable)、偏好开关、实时转录、对话气泡 |
| 3 | 屏幕 | `ScreenPage.ets` | 312 | `@Component` | 屏幕/Canvas状态面板：状态码(not_connected/node_unavailable/ready/pending/error)、URL信息、刷新按钮 |
| 4 | 设置 | `SettingsPage.ets` | 481 | `@Component` | 设备配置：Node/Voice/Camera/Location/Gateway/Advanced/About 7个配置区段 |

**所有 Tab 页面共同模式**：

```typescript
@Component
export struct XxxPage {
  @ObjectLink viewModel: MainViewModel;           // 共享ViewModel
  @StorageProp('localeVersion') localeVersion: number = 0;  // 国际化
  @State xxxState: ... = ...;                      // 本地同步状态
  private xxxListenerId: number = -1;              // 监听器ID

  aboutToAppear(): void {
    this.syncXxxState();
    this.xxxListenerId = this.viewModel.addXxxListener(() => { this.syncXxxState(); });
  }

  aboutToDisappear(): void {
    if (this.xxxListenerId >= 0) {
      this.viewModel.removeXxxListener(this.xxxListenerId);
    }
  }
}
```

### 2.4 引导页

| 文件 | 路径 | 行数 | 职责 |
|------|------|------|------|
| `OnboardingPage.ets` | `pages/` | 968 | 4步引导流程：Welcome → Gateway连接 → Permissions开关 → FinalCheck连接验证 |

### 2.5 ViewModel 层

| 文件 | 路径 | 行数 | 职责 |
|------|------|------|------|
| `MainViewModel.ets` | `viewmodel/` | 2118 | **整个应用的核心状态与业务逻辑中枢** |

**MainViewModel 核心架构**：

```typescript
@Observed
export class MainViewModel {
  // === 连接状态 ===
  isConnected: boolean = false;
  isNodeConnected: boolean = false;
  statusText: string = 'Offline';
  serverName / remoteAddress / isForeground

  // === 聊天状态 ===
  chatMessages / chatStreamingAssistantText / chatPendingToolCalls
  chatSessionKey / chatSessions / chatHealthOk / chatThinkingLevel
  chatError / pendingRunCount

  // === Canvas/Screen 状态 ===
  canvasCurrentUrl / canvasA2uiHydrated / canvasRehydratePending / canvasRehydrateErrorText

  // === 语音状态 ===
  micEnabled / micCooldown / micIsListening / micIsSending / micLiveTranscript
  micConversation / micQueuedMessages / micInputLevel / speakerEnabled

  // === 设备偏好 ===
  instanceId / displayName / cameraEnabled / locationMode / preventSleep
  manualEnabled / manualHost / manualPort / manualTls
  gatewayToken / gatewayBootstrapToken / gatewayPassword
  onboardingCompleted / canvasDebugStatusEnabled

  // === 双会话架构 ===
  private operatorSession: GatewaySession | null;  // Operator WebSocket (聊天/控制)
  private nodeSession: GatewaySession | null;       // Node WebSocket (设备能力/Canvas)

  // === 监听器系统 ===
  connectionStateListeners: ConnectionStateListenerEntry[];
  chatStateListeners: ChatStateListenerEntry[];
  addConnectionStateListener / removeConnectionStateListener
  addChatStateListener / removeChatStateListener
}
```

**双会话 (Operator + Node)** 是关键架构特征：
- **Operator 会话**：处理聊天、控制指令、健康检查、会话管理
- **Node 会话**：处理设备能力调用、Canvas 状态、invoke 指令分发
- 两者同时连接到同一 Gateway 端点，但角色不同

### 2.6 模型层

| 文件 | 路径 | 行数 | 职责 |
|------|------|------|------|
| `GatewayModels.ets` | `model/` | 76 | 数据模型类：GatewayEndpoint、ChatMessage/ChatMessageContent、ChatSessionEntry、ChatPendingToolCall、VoiceConversationEntry |

### 2.7 API/存储层

| 文件 | 路径 | 职责 |
|------|------|------|
| `GatewaySession.ets` | `api/` | WebSocket 会话管理：连接、断开、request/response 通信、事件流处理 |
| `SecurePrefs.ets` | `common/` | 安全偏好存储：所有持久化设置 (instanceId、display name、camera、location、mic、gateway等) |
| `IdentityStore.ets` | `api/` | 设备身份存储 |
| `DeviceIdentityStore.ets` | `api/` | 设备身份管理 |
| `DeviceAuthStore.ets` | `api/` | 设备认证存储 |
| `DeviceAuthPayload.ets` | `api/` | 认证载荷模型 |

### 2.8 Node 层 (设备能力)

| 文件 | 路径 | 职责 |
|------|------|------|
| `InvokeCommandRegistry.ets` | `node/` | 注册/查询设备可调用的 invoke 命令和能力 |
| `NodeInvokeDispatcher.ets` | `node/` | 分发和处理 Node invoke 请求，包含回调接口 |

---

## 三、状态传递与数据流

### 3.1 数据流向图

```
MainViewModel (@Observed, 单例 mainViewModel)
    ↓
    ├── PostOnboardingTabs (@ObjectLink viewModel)
    │       ├── ConnectPage  (@ObjectLink viewModel) + 本地 @State 同步
    │       ├── ChatPage     (@ObjectLink viewModel) + 本地 @State 同步
    │       ├── VoicePage    (@ObjectLink viewModel) + 本地 @State 同步
    │       ├── ScreenPage   (@ObjectLink viewModel) + 本地 @State 同步
    │       └── SettingsPage (@ObjectLink viewModel) + 本地 @State 同步
    │
    ├── Index (@State viewModel = mainViewModel)
    │       └── OnboardingPage (@ObjectLink viewModel)
    │
    └── EntryAbility (全局 AppStorage 注册 abilityContext/localeVersion)
```

### 3.2 监听器机制详解

各页面使用 **注册-注销** 模式在 ViewModel 上挂载监听器：

```
页面生命周期:
  aboutToAppear() → syncXxxState() + addXxxListener(callback)
  [ViewModel 属性变化时] → callback() → syncXxxState()
  aboutToDisappear() → removeXxxListener(listenerId)
```

**为什么使用监听器而非直接依赖 @Observed 响应式？**
因为各页面需要从 ViewModel 的众多属性中**选择性同步**到本地 `@State`，避免全量刷新，同时支持精细化的 UI 更新控制（如聊天消息滚动、状态颜色计算等）。

### 3.3 国际化机制

```
双通道国际化:
  1. @StorageProp('localeVersion') → 触发组件重渲染
  2. localizedText(name, fallback) → getContext(this).resourceManager.getStringByNameSync(name)

  EntryAbility.onForeground() → bumpLocaleVersion() → AppStorage.setOrCreate('localeVersion', current + 1)
  MainViewModel → getLocalizedString() → AppStorage.get<Context>('abilityContext').resourceManager...
```

---

## 四、Tab 切换机制深度解析

### 4.1 为什么不使用 HarmonyOS Tabs 容器？

当前实现使用 **if/else 条件渲染** 而非 `Tabs` + `TabContent` + `TabsController`。原因推测：

1. **自定义 TabBar 样式**：圆角选中态、渐变背景、固定高度58px，原生 Tabs 的 TabBar 定制灵活性有限
2. **条件渲染的性能优势**：仅渲染当前活跃 Tab，避免5个 TabContent 同时存在占用内存
3. **副作用控制**：`syncTabSideEffects()` 在切换时精确触发 Voice/Screen 的特定逻辑
4. **布局简洁性**：整个页面由 `Column(StatusBar + 内容区 + TabBar)` 构成，不依赖 Tabs 的复杂嵌套

### 4.2 Tab 切换生命周期

```
用户点击 TabItem(index)
  → onClick: if (this.activeTab === index) return;  // 防重复
  → this.activeTab = index;
  → syncTabSideEffects()
      → if (activeTab === 2): viewModel.setVoiceScreenActive(true)
      → if (activeTab === 3 && !screenTabPrimed): viewModel.refreshHomeCanvasOverviewIfConnected()
  → ArkUI 感知 activeTab 变化 → 条件渲染重建
      → 旧 Page 的 aboutToDisappear() → removeListener
      → 新 Page 的 aboutToAppear() → syncState + addListener
```

### 4.3 screenTabPrimed 机制

`screenTabPrimed` 是一个只初始化一次的标记，确保首次进入 Screen Tab 时触发 Canvas 状态刷新，但后续切换不再重复触发：

```typescript
if (this.activeTab === 3 && !this.screenTabPrimed) {
  this.screenTabPrimed = true;
  this.viewModel.refreshHomeCanvasOverviewIfConnected();
}
```

---

## 五、各 Tab 页面结构模式

### 5.1 ConnectPage (连接)

**结构**: `Scroll → Column → Header + ActiveEndpointCard + StatusCard + PrimaryActionButton + AdvancedToggle + [AdvancedControlsCard]`

**本地状态**: `inputMode`(SetupCode/Manual), `setupCode`, `manualHost/Port/Tls`, `gatewayToken/Password`, `advancedOpen`, `validationText`, `connectedState`, `statusState`, `remoteAddressState`

**监听器**: `addConnectionStateListener`

### 5.2 ChatPage (聊天)

**结构**: `Column → ChatHeader + ChatErrorRail + MessagesList + Composer`

**本地状态**: `messageText`, `showThinkingOptions`, `showSessionList`, `chatMessagesState`, `chatStreamingTextState`, `chatPendingToolCallsState`, `chatErrorState`, `chatHealthOkState`, `chatThinkingLevelState`, `chatSessionKeyState`, `chatSessionsState`, `pendingRunCountState`

**监听器**: `addChatStateListener`

**特殊**: 使用 `@luvi/lv-markdown-in` 的 Markdown 组件渲染消息，3个 MarkdownController (streaming/user/openclaw) 分别配置不同样式

### 5.3 VoicePage (语音)

**结构**: `Scroll → Column → Header + StatusSection + PreferencesSection + [LiveTranscriptSection] + ConversationSection`

**本地状态**: 无额外本地状态（直接读取 viewModel 属性），依赖 ViewModel 的 `micEnabled/micCooldown/micIsSending/micConversation/micLiveTranscript` 等

**监听器**: 无独立监听器（通过 PostOnboardingTabs 的连接状态监听间接更新）

**状态码系统**: `voiceStateCode()` → ready/busy/disabled/unavailable，每种状态对应不同的文本/背景/边框颜色

### 5.4 ScreenPage (屏幕)

**结构**: `Scroll → Column → Header + StatusSection + CanvasSection`

**本地状态**: 无额外本地状态，直接读取 `viewModel.canvasCurrentUrl/canvasA2uiHydrated/canvasRehydratePending/canvasRehydrateErrorText`

**监听器**: 无独立监听器

**状态码系统**: `screenStateCode()` → not_connected/node_unavailable/canvas_unavailable/pending/ready/error

### 5.5 SettingsPage (设置)

**结构**: `Scroll → Column → Header + NodeSection + VoiceSection + CameraSection + LocationSection + GatewaySection + AdvancedSection + AboutSection`

**本地状态**: `displayName`, `cameraEnabled`, `locationMode`, `locationPrecise`, `preventSleep`, `micEnabled`, `speakerEnabled`, `manualEnabled/Host/Port/Tls`, `canvasDebugStatus`, `appVersion`

**监听器**: 无独立监听器（`aboutToAppear` 时从 ViewModel loadSettings）

---

## 六、设计模式与复用组件

### 6.1 通用 Builder 模式

以下 Builder 在多个页面中重复出现，属于**可提取的共享组件**：

| Builder | 使用页面 | 描述 |
|---------|----------|------|
| `InfoRow(label, value)` | Voice/Screen/Settings | 左侧标签、右侧值的行布局 |
| `DividerLine()` | Voice/Screen/Settings | 简单分割线 |
| `SettingToggle(title, desc, isOn, onChange)` | Voice/Settings | 标题+描述+开关的行布局 |
| `localizedText(name, fallback)` | 所有页面 | 国际化文本获取 |

### 6.2 状态码 → 颜色映射模式

VoicePage 和 ScreenPage 都使用相同的模式：

```typescript
private xxxStateCode(): string { ... }  // 状态码计算
private xxxStateLabel(): string { ... }  // 状态码 → 文本
private xxxStateDescription(): string { ... }  // 状态码 → 描述
private xxxStateTextColor(): string { ... }  // 状态码 → 文字色
private xxxStateBgColor(): string { ... }   // 状态码 → 背景色
private xxxStateBorderColor(): string { ... }  // 状态码 → 边框色
```

颜色体系统一：
- Connected/Ready → 绿色系 (#2F8C5A / #E8F5EC / #BEE0CA)
- Connecting/Pending → 蓝色系 (#1D5DD8 / #ECF3FF / #D5E2FA)
- Warning/Disabled → 黄色系 (#C8841A / #FFF4DE / #F0D19A)
- Error → 红色系 (#DC2626 / #FFF5F5 / #F3C8C8)
- Offline/Unavailable → 灰色系 (#8A92A2 / #F6F7FA / #E5E7EC)

---

## 七、新增 Tab 页面的操作指南

基于以上框架分析，新增一个 Tab 需要以下步骤：

### 7.1 步骤清单

1. **创建新 Page 文件**: `entry/src/main/ets/pages/NewPage.ets`
   - 遵循 `@Component export struct NewPage { @ObjectLink viewModel: MainViewModel; @StorageProp('localeVersion') ... }` 模式
   - 在 `aboutToAppear/aboutToDisappear` 中注册/注销监听器（如果需要）
   - 使用 `Scroll → Column → Header + Sections` 的布局模式
   - 使用 `localizedText(name, fallback)` 国际化

2. **在 MainViewModel 中添加新状态字段**（如果新 Tab 有独有状态）
   - 在 `@Observed export class MainViewModel` 中添加 `@State` 属性
   - 添加对应的监听器系统（`addXxxListener / removeXxxListener / notifyXxxStateChanged`）或复用已有监听器
   - 在 `loadPreferences()` 中加载持久化偏好（如需要）
   - 添加 setter 方法 + SecurePrefs 存储（如需要）

3. **修改 PostOnboardingTabs.ets**
   - 在条件渲染区域新增 `else if (this.activeTab === N)` 分支
   - 在 `TabBar` Builder 中新增 `this.TabItem(N, localizedText('tab_xxx', 'Label'), 'emoji')`
   - 如有切换副作用，在 `syncTabSideEffects()` 中添加处理

4. **添加国际化资源**
   - 在 `resources/base/element/string.json` 添加 `tab_xxx` 和所有新页面文本 key
   - 在 `resources/zh_CN/element/string.json` 添加中文翻译
   - 在 `resources/en_US/element/string.json` 添加英文翻译

5. **添加数据模型**（如需要）
   - 在 `GatewayModels.ets` 中添加新的模型类

6. **在 GatewaySession/MainViewModel 中添加新协议**（如新 Tab 需要与 Gateway 通信）
   - 在 `handleEvent` switch 中添加新事件类型
   - 添加 request 方法调用

### 7.2 新 Tab 的典型代码骨架

```typescript
import { MainViewModel } from '../viewmodel/MainViewModel';

@Component
export struct NewTabPage {
  @ObjectLink viewModel: MainViewModel;
  @StorageProp('localeVersion') localeVersion: number = 0;

  @State localState: string = '';

  private xxxListenerId: number = -1;

  aboutToAppear(): void {
    this.syncState();
    this.xxxListenerId = this.viewModel.addXxxListener(() => { this.syncState(); });
  }

  aboutToDisappear(): void {
    if (this.xxxListenerId >= 0) {
      this.viewModel.removeXxxListener(this.xxxListenerId);
      this.xxxListenerId = -1;
    }
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.Header();
        this.StatusSection();
        this.ContentSection();
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 24 });
    }
    .width('100%')
    .height('100%');
  }

  @Builder Header() {
    Column({ space: 6 }) {
      Text(this.localizedText('xxx_header_eyebrow', 'XXX'))
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#1D5DD8');
      Text(this.localizedText('xxx_header_title', 'New Tab'))
        .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#17181C');
      Text(this.localizedText('xxx_header_subtitle', '...'))
        .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#4D5563');
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  private syncState(): void { ... }

  private localizedText(name: string, fallback: string): string {
    try {
      void this.localeVersion;
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (error) {
      console.warn('NewTabPage: localizedText failed for key: ' + name);
      return fallback;
    }
  }
}
```

### 7.3 PostOnboardingTabs 改动点

```typescript
// 条件渲染新增分支 (约51-61行区域)
} else if (this.activeTab === 5) {
  NewTabPage({ viewModel: this.viewModel });
}

// TabBar 新增项 (约106-113行区域)
this.TabItem(5, this.localizedText('tab_xxx', 'Label'), '🎯');

// syncTabSideEffects 新增副作用 (约38-44行区域)
if (this.activeTab === 5 && !this.xxxTabPrimed) {
  this.xxxTabPrimed = true;
  this.viewModel.xxxInitAction();
}
```

---

## 八、关键架构约束与注意事项

1. **不使用 Tabs 容器**：坚持 if/else 条件渲染模式，保持一致性
2. **共享 ViewModel**：所有页面通过 `@ObjectLink` 接入同一个 `mainViewModel` 单例
3. **监听器必须注销**：`aboutToDisappear` 中必须 `removeXxxListener`，否则内存泄漏
4. **国际化双通道**：新文本 key 必须同时添加到 base/zh_CN/en_US 三个 string.json
5. **页面路由只有 Index**：`main_pages.json` 只注册 `pages/Index`，新页面不需要注册路由
6. **颜色体系统一**：遵循已有的绿/蓝/黄/红/灰颜色映射体系
7. **Header 模式统一**：eyebrow(12px蓝粗) + title(24px黑粗) + subtitle(14px灰中)
8. **卡片模式统一**：`padding(14)` + `backgroundColor('#FFFFFF')` + `borderRadius(14)` + `border(width:1, color:'#E5E7EC')`
9. **Builder 复用优先**：InfoRow、DividerLine、SettingToggle 等通用 Builder 应提取为共享组件而非每页重复
10. **双会话架构**：新 Tab 如需 Gateway 通信，需区分使用 operatorSession(聊天/控制) 还是 nodeSession(设备能力)

---

## 九、实际项目文件树（已验证）

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets              # UIAbility 入口
├── pages/
│   ├── Index.ets                     # @Entry 路由页面
│   ├── OnboardingPage.ets            # 4步引导页
│   ├── PostOnboardingTabs.ets        # ★ 5 Tab 宿主组件
│   ├── ConnectPage.ets               # Tab 0 - 连接
│   ├── ChatPage.ets                  # Tab 1 - 聊天
│   ├── VoicePage.ets                 # Tab 2 - 语音
│   ├── ScreenPage.ets                # Tab 3 - 屏幕
│   ├── SettingsPage.ets              # Tab 4 - 设置
├── viewmodel/
│   └── MainViewModel.ets             # ★ 核心 ViewModel (2118行)
├── model/
│   └── GatewayModels.ets             # 数据模型类
├── api/
│   ├── GatewaySession.ets            # WebSocket 会话
│   ├── IdentityStore.ets             # 身份存储
│   ├── DeviceIdentityStore.ets       # 设备身份
│   ├── DeviceAuthStore.ets           # 认证存储
│   ├── DeviceAuthPayload.ets         # 认证载荷
├── common/
│   └── SecurePrefs.ets               # 安全偏好存储
├── node/
│   ├── InvokeCommandRegistry.ets     # 命令注册表
│   ├── NodeInvokeDispatcher.ets      # 命令分发器
└── protocol/
    └── OpenClawProtocolConstants.ets  # 协议常量

entry/src/main/resources/
├── base/
│   ├── element/string.json           # 默认字符串资源
│   ├── profile/main_pages.json       # 页面路由配置 (只有 pages/Index)
├── zh_CN/element/string.json         # 中文字符串
├── en_US/element/string.json         # 英文字符串
```