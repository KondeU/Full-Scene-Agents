# AgentCards UI 框架设计文档

> 目标：构建运行于鸿蒙系统的 AgentCards UI 框架，通过 JSON 数据驱动 + 脚本槽位机制，实现 Agent 输出的可视化呈现。UI 框架定义槽位，外部数据填充槽位，达到通用可扩展。

## 1. 核心设计理念

**槽位驱动 (Slot-driven)**：UI 框架只定义"槽位"（展示位 + 行为位），槽位内容由外部 JSON 文件和脚本文件填充。Agent 将输出写入 JSON，UI 实时读取渲染；用户交互触发脚本执行，脚本也是预留槽位，后期可自定义行为。

```
Agent 输出 ──→ JSON 文件 ──→ UI 槽位渲染 ──→ 用户可见
用户交互 ──→ 脚本槽位 ──→ action/take ──→ 后期自定义行为
```

## 2. 文件系统约定

### 2.1 目录结构

```
AGENT_CARDS_ROOT/                          ← 常量 AGENT_CARDS_ROOT = "storage/media/100/local/files/Docs/Download/AgentCards"
├── 1.快递信息聚合主动提醒/               ← AgentApp 目录
│   ├── config.json                        ← 通用配置槽位
│   ├── list/
│   │   ├── 1.json                         ← 卡片数据槽位
│   │   ├── 2.json                         ← 卡片数据槽位
│   │   ├── 3.json                         ← 卡片数据槽位
│   │   └── ...                            ← 按数字编号, 可动态增减
│   ├── action.js                          ← 行为槽位: 卡片按钮触发脚本
│   └── take.js                            ← 行为槽位: 图片导入触发脚本
├── 2.另一个Agent应用/
│   ├── config.json
│   ├── list/
│   │   ├── 1.json
│   │   └── ...
│   ├── action.js
│   └── take.js
├── ...
```

### 2.2 命名规则

| 层级 | 格式 | 说明 |
|------|------|------|
| AgentApp 目录 | `[number].[agent_app_name]` | `number` 用于内部标识和排序遍历，`agent_app_name` 为展示名称 |
| 卡片数据文件 | `[number].json` | 位于 `list/` 子目录下，`number` 为卡片编号，也是 action 脚本的入参 |
| 行为脚本 | `action.js` / `take.js` | 位于 AgentApp 目录下，为预留的行为槽位 |
| 通用配置 | `config.json` | 位于 AgentApp 目录下，为预留的配置槽位 |

### 2.3 config.json 配置格式

每个 AgentApp 目录下可选的配置文件，不存在时所有字段按默认值处理：

```json
{
  "ascendingOrder": true
}
```

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| ascendingOrder | boolean | true | 卡片排序方向，true=升序(number从小到大)，false=降序(number从大到小) |

> 后续可扩展更多配置字段，UI 框架按字段存在性决定是否使用，不存在则 fallback 到默认值。

### 2.4 卡片 JSON 数据格式

每个 `[number].json` 文件为一个卡片的数据槽位：

```json
{
  "title": "幸福里1栋快递驿站",
  "line0": "取件码: 3-1-8810、5-2-3316",
  "line1": "驿站营业时间: 8:00~20:00",
  "buttonText": "我已取件"
}
```

| 字段 | 类型 | 说明 | 是否必填 |
|------|------|------|---------|
| title | string | 卡片标题栏文本 | 是 |
| line0 | string | 卡片第一行文本 | 是 |
| line1 | string | 卡片第二行文本 | 否 (空则不渲染) |
| buttonText | string | 按钮显示文本 | 否 (空则不渲染按钮，不响应点击) |

> 后续可扩展更多字段（如 line2、icon、status 等），UI 框架按字段存在性决定是否渲染对应槽位。

### 2.5 脚本函数入口约定

`action.js` 和 `take.js` 必须导出约定的函数入口名：

**action.js**：
```javascript
function action(cardNumber) {
  // cardNumber: 卡片编号, 如 1
  // 后期可自定义行为逻辑
}
```

**take.js**：
```javascript
function take(imageUri) {
  // imageUri: 图片 URI/路径, 如 "file:///storage/media/100/local/files/Docs/photo.jpg"
  // 后期可自定义行为逻辑
}
```

脚本通过 WebJS 引擎加载执行。UI 框架读取脚本文件内容后，通过 `evaluateJs` 拼接调用：
```
evaluateJs(scriptContent + "; action(" + cardNumber + ")")
evaluateJs(scriptContent + "; take('" + imageUri + "')")
```

脚本不存在时，console log 输出警告信息，UI 不做额外提示。

## 3. 页面与交互流程

### 3.1 页面总览

```
页面1: 主页 (AgentAppListPage)     ──  展示 AgentCards 目录下的所有 AgentApp
页面2: 展示页 (AgentAppDetailPage) ──  展示选中 AgentApp 的卡片列表 + 图片导入
```

### 3.2 主页 — AgentApp 列表

用户点击应用图标后进入主页，展示 `AGENT_CARDS_ROOT` 目录下所有子目录名称。

```
┌───────────────────────────────────┐
│    AgentCards              [🔄]   │  ← 标题栏 + 右上角刷新按钮
│                                   │
│  ┌─────────────────────────────┐  │
│  │  快递信息聚合主动提醒       │  │  ← 目录名 "1.快递信息聚合主动提醒"
│  │                              │  │    前缀 "1." 不展示, 仅内部排序用
│  └─────────────────────────────┘  │
│                                   │
│  ┌─────────────────────────────┐  │
│  │  另一个Agent应用             │  │
│  └─────────────────────────────┘  │
│                                   │
│  ┌─────────────────────────────┐  │
│  │  ...                        │  │
│  └─────────────────────────────┘  │
│                                   │
│  (列表按 number 升序排列, 可滚动)  │
│                                   │
│  若目录为空: "暂无AgentApp"        │
└───────────────────────────────────┘
```

**交互流程**：
```
1. 遍历 AGENT_CARDS_ROOT 目录下的子目录
2. 解析 "[number].[agent_app_name]" 格式
3. 按 number 升序排列
4. 列表项展示 agent_app_name (去掉前缀 number 和 ".")
5. 点击列表项 → Router.pushUrl(AgentAppDetailPage, { dirName: "1.快递信息聚合主动提醒" })
6. 点击刷新按钮 → 重新扫描目录并刷新列表
7. 从后台切回前台 → onPageShow 自动触发一次刷新
```

### 3.3 展示页 — AgentApp 详情 (双 Tab)

点击主页列表项后进入展示页，底部两个 Tab 页。

```
┌───────────────────────────────────┐
│  ← 快递信息聚合主动提醒    [🔄]  │  ← 顶部导航: 返回按钮 + AgentApp名称 + 刷新按钮
│                                   │
│  ┌─────────────────────────────┐  │
│  │                             │  │  ← Tab 内容区
│  │  (Tab1: 卡片列表 /          │  │
│  │   Tab2: 图片导入)           │  │
│  │                             │  │
│  └─────────────────────────────┘  │
│                                   │
│  ┌──────────┬──────────────────┐  │
│  │  卡片列表 │    图片导入      │  │  ← 底部 TabBar (固定两个Tab)
│  └──────────┴──────────────────┘  │
└───────────────────────────────────┘
```

#### Tab 1: 卡片聚合列表

呈现多个卡片聚合形式的列表，数据来自 `list/[number].json` 文件。

```
┌───────────────────────────────────┐
│  ← 快递信息聚合主动提醒    [🔄]  │
│                                   │
│  ┌─────────────────────────────┐  │
│  │  幸福里1栋快递驿站          │  │  ← title (标题栏)
│  │  取件码: 3-1-8810、5-2-3316 │  │  ← line0
│  │  驿站营业时间: 8:00~20:00    │  │  ← line1
│  │                    [我已取件]│  │  ← buttonText → 点击执行 action.js
│  └─────────────────────────────┘  │
│                                   │
│  ┌─────────────────────────────┐  │
│  │  科技园A区快递驿站          │  │
│  │  运单号: 1-1088             │  │
│  │  驿站营业时间: 7:00~19:00    │  │
│  │                    [我已取件]│  │
│  └─────────────────────────────┘  │
│                                   │
│  ┌─────────────────────────────┐  │
│  │  ...更多卡片...              │  │  ← 按 config.json 中 ascendingOrder 排序
│  └─────────────────────────────┘  │
│                                   │
│  若列表为空: "暂无卡片数据"        │
│                                   │
│  ┌──────────┬──────────────────┐  │
│  │  卡片列表 │    图片导入      │  │
│  └──────────┴──────────────────┘  │
└───────────────────────────────────┘
```

**卡片组件结构 (AgentCard)**：

```
┌─────────────────────────────┐
│  title                      │  ← 标题栏 (强调色/加粗)
│                             │
│  line0                      │  ← 第一行文本
│  line1                      │  ← 第二行文本 (可选, 无则不渲染)
│                             │
│                   [buttonText]│  ← 按钮, 右对齐 (可选, 无则不渲染)
└─────────────────────────────┘
```

**按钮交互流程**：
```
用户点击卡片按钮 → 读取卡片编号 [number]
→ 读取 action.js 脚本文件内容
→ WebJS 引擎 evaluateJs(scriptContent + "; action(" + number + ")")
→ action.js 为预留槽位, 后期可自定义行为
```

#### Tab 2: 图片导入

呈现拍照/相册导入图片功能。

```
┌───────────────────────────────────┐
│  ← 快递信息聚合主动提醒    [🔄]  │
│                                   │
│  ┌─────────────────────────────┐  │
│  │                             │  │
│  │     ┌─────────────────┐     │  │
│  │     │                 │     │  │  ← 图片预览区
│  │     │   (预览图)       │     │  │    拍照/选择后显示
│  │     │                 │     │  │
│  │     └─────────────────┘     │  │
│  │                             │  │
│  │  ┌──────┐    ┌──────────┐  │  │
│  │  │ 拍照 │    │ 从相册选择│  │  │  ← 拍照 / 相册按钮
│  │  └──────┘    └──────────┘  │  │
│  │                             │  │
│  └─────────────────────────────┘  │
│                                   │
│  ┌──────────┬──────────────────┐  │
│  │  卡片列表 │    图片导入      │  │
│  └──────────┴──────────────────┘  │
└───────────────────────────────────┘
```

**图片导入交互流程**：
```
用户选择拍照或从相册导入 → 获取图片 URI
→ 图片预览区展示选中图片
→ 读取 take.js 脚本文件内容
→ WebJS 引擎 evaluateJs(scriptContent + "; take('" + imageUri + "')")
→ take.js 为预留槽位, 后期可自定义行为
```

## 4. 完整交互时序

```
┌─────────┐     ┌──────────┐     ┌───────────┐     ┌──────────┐
│  用户    │     │  UI框架   │     │  文件系统  │     │ WebJS引擎│
└────┬────┘     └─────┬────┘     └─────┬─────┘     └────┬─────┘
     │                │                │                │
     │ 点击App图标    │                │                │
     │──────────────→│                │                │
     │                │ 遍历AGENT_CARDS_ROOT             │
     │                │──────────────→│                │
     │                │ 子目录列表     │                │
     │                │←─────────────│                │
     │ 展示AgentApp列表│                │                │
     │←──────────────│                │                │
     │                │                │                │
     │ 点击列表项     │                │                │
     │──────────────→│                │                │
     │                │ 读取config.json│                │
     │                │──────────────→│                │
     │                │ config或不存在 │                │
     │                │←─────────────│                │
     │                │ 遍历list/*.json│                │
     │                │──────────────→│                │
     │                │ JSON卡片数据   │                │
     │                │←─────────────│                │
     │ 展示卡片列表   │                │                │
     │←──────────────│                │                │
     │                │                │                │
     │ 点击卡片按钮   │                │                │
     │──────────────→│                │                │
     │                │ 读取action.js  │                │
     │                │──────────────→│                │
     │                │ action.js内容  │                │
     │                │←─────────────│                │
     │                │ evaluateJs(actionScript + "; action(N)")│
     │                │──────────────────────────────→│
     │                │                │                │
     │ (Tab2) 拍照/选图│                │                │
     │──────────────→│                │                │
     │                │ 读取take.js    │                │
     │                │──────────────→│                │
     │                │ take.js内容    │                │
     │                │←─────────────│                │
     │                │ evaluateJs(takeScript + "; take('imageUri')")│
     │                │──────────────────────────────→│
     │                │                │                │
     │ 点击刷新按钮   │                │                │
     │──────────────→│ 重新扫描目录   │                │
     │                │──────────────→│                │
     │ 刷新后的列表   │                │                │
     │←──────────────│                │                │
     │                │                │                │
     │ (从后台切回前台)│                │                │
     │ onPageShow     │ 自动触发刷新   │                │
     │──────────────→│──────────────→│                │
```

## 5. 数据刷新机制

不做文件监听或定时轮询，采用以下组合策略：

| 策略 | 触发方式 | 说明 |
|------|---------|------|
| **手动刷新** | 页面右上角刷新按钮 | 用户主动点击触发扫描目录并刷新 |
| **自动刷新** | `onPageShow` 生命周期 | 从后台切回前台时自动触发一次刷新，用户无感知 |

**刷新逻辑**：
```
触发刷新 → 重新扫描 AGENT_CARDS_ROOT 子目录 (主页)
         → 或重新扫描 list/*.json + 读取 config.json (展示页)
         → 解析 JSON → 更新 @State 数据 → UI 自动重渲染
```

**错误处理**：JSON 解析失败、脚本不存在、脚本执行失败等异常，均在 console log 中详细记录，不做 UI 层面的错误提示弹窗。

## 6. 权限与安全

- **目录访问权限**：通过固定权限声明（`module.json5` 中声明），用户安装应用时授权，赋予 `AGENT_CARDS_ROOT` 目录的读写访问权限
- **脚本执行**：通过 WebJS 引擎绕过鸿蒙 HAP 沙箱限制，脚本在 Web 组件的 JS 上下文中执行
- **路径常量**：`AGENT_CARDS_ROOT` 路径定义为字符串常量，代码中统一引用，避免硬编码散落各处

## 7. 组件与模块设计

### 7.1 数据模型

```typescript
// AgentApp 目录项
class AgentAppEntry {
  number: number;            // 目录前缀编号, 如 1
  appName: string;           // 展示名, 如 "快递信息聚合主动提醒"
  dirName: string;           // 完整目录名, 如 "1.快递信息聚合主动提醒"
  fullPath: string;          // 完整路径
}

// 卡片数据 (对应一个 [number].json)
class CardData {
  number: number;            // 卡片编号, 如 1 (也是 action 入参)
  title: string;             // 标题栏
  line0: string;             // 第一行文本
  line1?: string;            // 第二行文本 (可选)
  buttonText?: string;       // 按钮文本 (可选)
  sourcePath: string;        // JSON 文件完整路径
}

// AgentApp 配置 (对应 config.json, 所有字段有默认值)
class AgentAppConfig {
  ascendingOrder: boolean = true;  // 卡片排序方向, 默认升序
}
```

### 7.2 核心组件

```
AgentAppListComponent    ← 主页列表组件, 渲染 AgentAppEntry[]
AgentCardComponent       ← 单个卡片组件, 渲染 CardData (title + line0 + line1 + button)
CardListComponent        ← 卡片聚合列表组件, 渲染 CardData[] (含空态提示)
ImageImportComponent     ← 图片导入组件, 拍照/相册选择 + 预览
AgentAppDetailView       ← 展示页整体布局, 组合 Tab + CardList + ImageImport
```

### 7.3 模块划分

```
features/
├── agentCardContainer/               ← 核心: AgentCards 框架 feature
│   ├── src/main/ets/
│   │   ├── view/
│   │   │   ├── AgentAppListComponent.ets      ← 主页列表
│   │   │   ├── AgentCardComponent.ets         ← 单卡片
│   │   │   ├── CardListComponent.ets          ← 卡片聚合列表
│   │   │   ├── ImageImportComponent.ets       ← 图片导入
│   │   │   └── AgentAppDetailView.ets         ← 展示页双Tab布局
│   │   ├── viewmodel/
│   │   │   ├── AgentAppListViewModel.ets      ← 遍历目录, 解析子目录
│   │   │   ├── CardListViewModel.ets          ← 遍历list/*.json, 解析卡片数据
│   │   │   └── ScriptExecutor.ets             ← WebJS引擎加载执行脚本
│   │   ├── model/
│   │   │   ├── AgentAppEntry.ets              ← AgentApp目录项模型
│   │   │   ├── CardData.ets                   ← 卡片数据模型
│   │   │   ├── AgentAppConfig.ets             ← 配置模型
│   │   │   └── ScriptSlot.ets                 ← 脚本槽位模型
│   │   ├── utils/
│   │   │   ├── DirectoryScanner.ets           ← 目录遍历与排序
│   │   │   └── JsonParser.ets                 ← JSON解析与校验
│   │   ├── constants/
│   │   │   └── CommonConstants.ets            ← 含 AGENT_CARDS_ROOT 等路径常量
│   │   └── pages/
│   │       ├── AgentAppListPage.ets           ← 主页入口
│   │       └── AgentAppDetailPage.ets         ← 展示页
│   └── Index.ets
│
├── responsiveLayout/      ← 保留
├── adaptiveLayout/        ← 保留
│
common/
├── src/main/ets/
│   ├── utils/
│   │   ├── BreakpointSystem.ets       ← 保留
│   │   └── Logger.ets                 ← 保留
│   ├── constants/CommonConstants.ets
```

## 8. 响应式适配

继承现有 BreakpointSystem (sm/md/lg/xl)，在展示页做差异化布局：

| 断点 | 卡片列表布局 | 图片导入布局 | 说明 |
|------|------------|------------|------|
| sm (0-600vp) | 单列竖向卡片 | 纵向: 预览+按钮 | 手机竖屏 |
| md (600-840vp) | 双列卡片网格 | 纵向: 预览+按钮 | 手机横屏/小平板 |
| lg (840-1320vp) | 双列卡片网格 | 预览区+按钮横向 | 平板 |
| xl (≥1320vp) | 三列卡片网格 | 预览区+按钮横向 | PC/智慧屏 |

## 9. 脚本槽位机制

### 9.1 action 槽位

- **触发时机**：用户点击卡片按钮
- **脚本位置**：`AgentCards/[number].[agent_app_name]/action.js`
- **函数入口**：`function action(cardNumber)` — cardNumber 为卡片编号
- **执行方式**：读取脚本文件内容 → WebJS evaluateJs 拼接调用
- **性质**：预留槽位，初始可为空脚本或占位脚本，后期替换为具体行为逻辑

### 9.2 take 槽位

- **触发时机**：用户拍照或从相册导入图片后
- **脚本位置**：`AgentCards/[number].[agent_app_name]/take.js`
- **函数入口**：`function take(imageUri)` — imageUri 为图片 URI/路径
- **执行方式**：读取脚本文件内容 → WebJS evaluateJs 拼接调用
- **性质**：预留槽位，初始可为空脚本或占位脚本，后期替换为具体行为逻辑

### 9.3 扩展性

后续可新增更多行为槽位，如：

| 槽位名 | 触发时机 | 函数入口 | 入参 | 说明 |
|--------|---------|---------|------|------|
| `refresh.js` | 用户点击刷新按钮 | `function refresh()` | 无 | 自定义刷新后行为 |
| `longpress.js` | 用户长按卡片 | `function longpress(cardNumber)` | [number] | 卡片长按行为 |
| `swipe.js` | 用户滑动卡片 | `function swipe(cardNumber, direction)` | number + 方向 | 卡片滑动行为 |

新增槽位只需在 AgentApp 目录下放置对应名称的脚本文件，UI 框架按约定名称查找并执行。

## 10. 视觉规范

| 要素 | 规范 |
|------|------|
| 页面背景 | `$r('sys.color.ohos_id_color_sub_background')` |
| 卡片背景 | `$r('sys.color.ohos_id_color_card_background')` 或白色 |
| 卡片圆角 | 16vp |
| 卡片间距 | 12vp (竖向), 12vp (横向) |
| 标题栏文字 | ohos_id_color_text_primary, FontWeight.Bold, 16fp |
| 内容行文字 | ohos_id_color_text_secondary, FontWeight.Regular, 14fp |
| 按钮样式 | 系统强调色背景, 白色文字, 圆角按钮 |
| 列表项样式 | 系统色背景, 右侧箭头指示 |
| Tab 样式 | 遵循 HarmonyOS Tabs 组件标准样式 |
| 刷新按钮 | 页面右上角, 使用系统 SymbolGlyph refresh 图标 |
| 空态提示 | 居中灰色文字, "暂无卡片数据" / "暂无AgentApp" |