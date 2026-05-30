# AgentCards 代码生成记录

> 时间: 2026-05-30
> 依据: designs/ui-design.md (最终讨论确认版)

## 1. 生成范围

新增 feature 模块 `agentCardContainer`，以及修改现有项目配置文件使其接入新模块。

## 2. 新增文件清单

### 模块配置 (feature infrastructure)

| 文件 | 说明 |
|------|------|
| `features/agentCardContainer/build-profile.json5` | HAR 模块构建配置，沿用 responsiveLayout 模板 |
| `features/agentCardContainer/oh-package.json5` | 包名 `@ohos/agentcardcontainer`，依赖 `@ohos/common` |
| `features/agentCardContainer/src/main/module.json5` | HAR 类型，支持 phone/tablet |
| `features/agentCardContainer/Index.ets` | 导出全部 model/viewmodel/view/utils/constants |
| `features/agentCardContainer/hvigorfile.ts` | Hvigor 构建入口 |
| `features/agentCardContainer/BuildProfile.ets` | 构建Profile占位 |
| `features/agentCardContainer/obfuscation-rules.txt` | 混淆规则(空) |
| `features/agentCardContainer/consumer-rules.txt` | 消费混淆规则(空) |

### model 数据模型

| 文件 | 类 | 关键字段 |
|------|-----|---------|
| `src/main/ets/model/AgentAppEntry.ets` | AgentAppEntry | number, appName, dirName, fullPath |
| `src/main/ets/model/CardData.ets` | CardData | number, title, line0, line1?, buttonText?, sourcePath |
| `src/main/ets/model/AgentAppConfig.ets` | AgentAppConfig | ascendingOrder(默认true) |
| `src/main/ets/model/ScriptSlot.ets` | ScriptSlot | name, scriptPath, functionName + ACTION_SLOT/TAKE_SLOT 静态工厂 |

### constants 常量

| 文件 | 关键常量 |
|------|---------|
| `src/main/ets/constants/CommonConstants.ets` | AGENT_CARDS_ROOT = `storage/media/100/local/files/Docs/Download/AgentCards`, CONFIG_FILE_NAME, LIST_DIR_NAME, ACTION_SCRIPT_NAME, TAKE_SCRIPT_NAME, 各种UI尺寸常量, 空态提示文本 |

### utils 工具

| 文件 | 类/方法 | 说明 |
|------|--------|------|
| `src/main/ets/utils/DirectoryScanner.ets` | scanAgentAppDirs() | 遍历AGENT_CARDS_ROOT，解析`[number].[appName]`格式，升序排列 |
| `src/main/ets/utils/DirectoryScanner.ets` | scanCardJsonFiles() | 遍历list/子目录，收集.json文件路径 |
| `src/main/ets/utils/JsonParser.ets` | parseCardData() | 解析卡片JSON，返回CardData或null |
| `src/main/ets/utils/JsonParser.ets` | parseConfig() | 解析config.json，不存在时返回默认值 |

### viewmodel 业务逻辑

| 文件 | 类/方法 | 说明 |
|------|--------|------|
| `src/main/ets/viewmodel/AgentAppListViewModel.ets` | getAgentAppList() | 调用DirectoryScanner获取AgentApp列表 |
| `src/main/ets/viewmodel/CardListViewModel.ets` | getCardList() | 扫描JSON+解析+按config排序 |
| `src/main/ets/viewmodel/CardListViewModel.ets` | getConfig() | 读取config.json获取AgentAppConfig |
| `src/main/ets/viewmodel/ScriptExecutor.ets` | executeAction() | 读取action.js内容→WebJS evaluateJs拼接`action(cardNumber)` |
| `src/main/ets/viewmodel/ScriptExecutor.ets` | executeTake() | 读取take.js内容→WebJS evaluateJs拼接`take('imageUri')` |

### view UI组件

| 文件 | 组件 | 说明 |
|------|------|------|
| `src/main/ets/view/AgentAppListComponent.ets` | AgentAppListComponent | 主页列表：标题栏+刷新按钮+AgentApp列表/空态 |
| `src/main/ets/view/AgentCardComponent.ets` | AgentCardComponent | 单卡片：title(加粗)+line0+line1(可选)+buttonText按钮(可选) |
| `src/main/ets/view/CardListComponent.ets` | CardListComponent | 卡片聚合列表+空态提示"暂无卡片数据" |
| `src/main/ets/view/ImageImportComponent.ets` | ImageImportComponent | 图片预览区+拍照按钮+相册选择按钮(PhotoViewPicker/CameraPicker) |
| `src/main/ets/view/AgentAppDetailView.ets` | AgentAppDetailView | 展示页整体：返回+标题+刷新+隐藏Web组件+双Tab(卡片列表/图片导入) |

### pages 页面

| 文件 | 页面 | 说明 |
|------|------|------|
| `src/main/ets/pages/AgentAppListPage.ets` | AgentAppListPage | 主页入口，aboutToAppear/onPageShow触发刷新，路由跳转AgentAppDetailPage |
| `src/main/ets/pages/AgentAppDetailPage.ets` | AgentAppDetailPage | 展示页，读取路由参数(dirName/fullPath/appName)，刷新卡片列表，WebJS执行脚本 |

### resources 资源

| 文件 | 说明 |
|------|------|
| `src/main/resources/base/element/string.json` | 中文字符串: 标题、Tab名、空态、按钮文本 |
| `src/main/resources/base/element/float.json` | 尺寸常量: 圆角、间距、字号 |

## 3. 修改的现有文件

| 文件 | 修改内容 |
|------|---------|
| `products/default/src/main/ets/pages/Index.ets` | 主页从目录列表改为AgentAppListComponent，引用`@ohos/agentcardcontainer` |
| `products/default/src/main/resources/base/profile/main_pages.json` | 新增 `pages/AgentAppListPage`, `pages/AgentAppDetailPage` |
| `products/default/oh-package.json5` | 新增依赖 `@ohos/agentcardcontainer: file:../../features/agentCardContainer` |
| `build-profile.json5` (root) | modules数组新增 agentCardContainer 条目 |
| `products/default/src/main/module.json5` | 新增 `requestPermissions`: `ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY` |
| `products/default/src/main/resources/base/element/string.json` | 新增 permission_reason 等中文字符串 |

## 4. 关键设计决策实现映射

| 设计决策 | 代码实现位置 |
|---------|-------------|
| AGENT_CARDS_ROOT 路径常量 | `commonConstants.AGENT_CARDS_ROOT` in CommonConstants.ets |
| `[number].[appName]` 格式解析 | `DirectoryScanner.scanAgentAppDirs()` 中 `dirName.match(/^(\d+)\.(.+)$/)` |
| config.json ascendingOrder 排序 | `CardListViewModel.getCardList()` 读取config后按升/降序排序 |
| config.json不存在时默认值 | `JsonParser.parseConfig()` 中 `fs.accessSync` 检测，不存在返回默认AgentAppConfig |
| 刷新按钮(手动刷新) | `AgentAppListComponent`/`AgentAppDetailView` 中右上角 `arrow_clockwise` SymbolGlyph |
| onPageShow 自动刷新 | `AgentAppListPage.onPageShow()` / `AgentAppDetailPage.onPageShow()` 调用refreshList/refreshCards |
| 空态提示 | `AgentAppListComponent` 中"暂无AgentApp"，`CardListComponent` 中"暂无卡片数据" |
| 卡片按钮 → action.js | `AgentAppDetailView.onActionClick` → `scriptExecutor.executeAction(agentAppPath, cardNumber)` |
| 图片导入 → take.js | `ImageImportComponent.onImageSelected` → `scriptExecutor.executeTake(agentAppPath, imageUri)` |
| WebJS 脚本执行 | `ScriptExecutor.executeScript()` 中 `webView.controller.runJavaScript(callExpr)` |
| 脚本不存在时 console warn | `ScriptExecutor.executeScript()` 中 `fs.accessSync` 检测后 logger.warn |
| READ_WRITE_DOWNLOAD_DIRECTORY 权限 | `products/default/module.json5` requestPermissions |

## 5. 待验证项

- 鸿蒙 `fileIo.listFileSync` 对公共目录 `storage/media/100/local/files/Docs/Download/` 的实际访问行为
- `PhotoViewPicker` / `CameraPicker` API 在 HarmonyOS 6.0.2 上的可用性及返回URI格式
- `webview.WebviewController.runJavaScript` 在隐藏 Web 组件上的执行可行性
- `ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY` 是否覆盖目标路径的读写权限
- 完整 HAP 构建编译是否通过