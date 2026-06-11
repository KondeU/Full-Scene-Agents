# 数据驱动桌面卡片 + updateReminderCard Tool + 调试 Tab — 详细设计方案

> 最小侵入式新增：优先创建新文件，尽量不修改已有代码。

---

## 一、需求摘要

1. **桌面卡片（Form Kit）**：支持两种渲染风格——
   - `infoShowTitleBodyNoteImage`（默认）：左右分栏布局，左边三行文字（标题、正文、备注），右边可选一张图；若无图则文字区自动扩展占满整行宽度
   - `infoShowTitleImageAndImport`（新增）：全幅背景图铺满卡片，右侧两个半透明操作按钮引导用户拍照/选图导入
2. **`updateReminderCard` 接口**：刷新卡片上的提醒内容；既作为本地 API 接口，又作为 Claw node invoke command（`card.reminder.update`），可被智能体通过 Gateway 调用。Agent 通过 `style` 参数实时选择渲染哪种卡片风格
3. **`skill` 参数（新增）**：可选配置，不参与卡片渲染。当用户通过卡片上的"拍一拍"或"选一选"拍照/选图后，`skill` 决定发送给 chat 的指令文本——非空时发 `/skill <值>`，空时默认发 `/ImageData`。用于 Agent 指定图片导入后的处理技能
4. **默认卡片内容**："当前无主动提醒"
5. **调试 Tab 页面**：新增"调试"tab（index=6），用于调试卡片内容推送、invoke command 响应、后续也可以复用给其他新增能力的调试
6. **最小侵入**：优先新增文件，对现有代码改动仅限于必要的位置

---

## 二、Form Kit 可行性分析

### 2.1 HarmonyOS Form Kit 是什么

HarmonyOS 的 **Form Kit**（也叫"卡片"或"服务卡片"）是系统级的桌面小组件框架。用户可以长按应用图标或从桌面卡片市场将卡片添加到桌面，卡片在独立进程中运行（FormExtension），不依赖主应用前台存活。

### 2.2 核心能力对照

| 维度 | 需求 | Form Kit 是否支持 |
|------|------|-------------------|
| 桌面常驻显示 | 卡片在桌面上持续可见 | ✅ 核心功能 |
| 左右分栏布局 | 左文字+右可选图 | ✅ ArkTS 声明式布局完整支持 |
| 无图时文字扩展 | 条件渲染/if-else 动态布局 | ✅ ArkTS 卡片支持条件渲染 |
| 数据驱动刷新 | 从应用/服务推送数据到卡片 | ✅ `formProvider.updateForm()` |
| 定时刷新 | 系统按 schedule 定时拉取 | ✅ `updateDuration` 配置 |
| 主应用触发刷新 | 调用 API 更新卡片 | ✅ `formProvider.updateForm()` |
| 点击卡片跳转 | 点击卡片回到主应用 | ✅ `formBindingData` + Want |

### 2.3 限制与约束

| 限制 | 说明 | 本项目应对 |
|------|------|------------|
| 卡片 UI 限制 | 不能用所有 ArkTS 组件，仅支持卡片专用的受限组件集 | 使用基础 `Column/Row/Text/Image`，完全在受限集内 |
| 卡片进程独立 | FormExtension 运行在独立进程，不能访问主应用内存 | 通过 `LocalData` / `AppStorage` 跨进程共享数据 |
| 刷新频率 | 系统对定时刷新有频率限制（最少 30 分钟/1 小时） | 使用主动推送（`formProvider.updateForm`）为主，定时刷新兜底 |
| 卡片尺寸 | 支持 1×2/2×2/2×4/4×4 等系统规范尺寸 | 选用 **2×2**（适合提醒类三行文字+可选小图）和 **2×4**（有图时更舒展） |
| 无动画/手势 | 卡片不支持动画、手势拖拽等 | 不需要，纯数据展示 |

### 2.4 结论：Form Kit 完全可行

本项目需求（三行文字+可选小图+数据驱动刷新）100% 落在 Form Kit 能力范围内。选用 **2×2** 和 **2×4** 两种尺寸规格，2×2 为默认添加尺寸。

---

## 三、改动范围总览

| 类型 | 文件 | 改动性质 | 改动量 |
|------|------|----------|--------|
| **新增** | `form/ReminderFormExtension.ets` | FormExtension 生命周期 | ~30 行 |
| **新增** | `form/pages/ReminderCardWidget.ets` | 卡片 UI（左右分栏布局） | ~120 行 |
| **新增** | `service/CardReminderService.ets` | 卡片数据管理 + updateReminderCard + invoke 处理 | ~120 行 |
| **新增** | `pages/DebugPage.ets` | 调试 Tab 页面 UI | ~200 行 |
| **新增** | `resources/base/profile/form_config.json` | 卡片配置（尺寸、刷新策略） | ~20 行 |
| **修改** | `module.json5` | 新增 extensionAbility + form 配置引用 + 权限 | ~15 行增量 |
| **修改** | `PostOnboardingTabs.ets` | 添加 import + 条件渲染分支 + TabItem | ~6 行增量 |
| **修改** | `InvokeCommandRegistry.ets` | 新增 `card.reminder.update` command spec | +3 行 |
| **修改** | `OpenClawProtocolConstants.ets` | 新增 `OpenClawCardCommand` enum | +5 行 |
| **修改** | `NodeInvokeDispatcher.ets` | 新增 card command 处理分支 | +5 行 |
| **修改** | `EntryAbility.ets` | onNewWant 处理卡片路由（targetPage + importAction） | +12 行 |
| **修改** | `ImportPage.ets` | aboutToAppear 读取 importAction 自动触发拍照/相册 | +8 行 |
| **修改** | `PhotoCaptureService.ets` | obtainPhotoToProcess 读 cardSkill 构造 chat 消息文本 | +4 行 |
| **修改** | 3 × `string.json` | 新增国际化 key（卡片+调试） | ~25 条/文件 |

**不改动**：`GatewaySession.ets`、`GatewayModels.ets`、`SecurePrefs.ets`、所有已有 Page（除 PostOnboardingTabs）、`DeviceAuthStore`、`DeviceIdentityStore`

---

## 四、架构设计

### 4.1 数据流总览

```
┌─────────────────────────────────────────────────────────────────┐
│                    Gateway (远程)                                │
│   AI 智能体 → node.invoke.request                               │
│   command: "card.reminder.update"                               │
│   paramsJson: { style?, title, body, note?, imageUrl? }         │
└───────────────────────────┬─────────────────────────────────────┘
                            │ WebSocket
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│             MainViewModel (主应用进程)                           │
│   GatewaySession.onInvoke → NodeInvokeDispatcher                │
│   → switch(command) → card.reminder.update                      │
│   → CardReminderService.handleUpdateReminderCommand()           │
└───────────────────────────┬─────────────────────────────────────┘
                            │ formProvider.updateForm()
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│          FormExtension (独立卡片进程)                             │
│   ReminderFormExtension.onUpdate()                              │
│   → ReminderCardWidget 读取 formBindingData                     │
│   → 根据 style 字段选择渲染模式:                                 │
│     • infoShowTitleBodyNoteImage: 左文字+右可选图（默认）        │
│     • infoShowTitleImageAndImport: 全幅背景图+右侧导入按钮       │
└─────────────────────────────────────────────────────────────────┘

                    ┌─────────────────┐
                    │  DebugPage      │
                    │  (主应用 Tab)    │
                    │  调试 UI:       │
                    │  手动推送测试    │
                    │  invoke 模拟    │
                    │  卡片状态查看    │
                    └─────────────────┘
```

### 4.2 双通道数据刷新

卡片数据的刷新有两个来源：

1. **本地 API 调用**（主应用内）：`CardReminderService.updateReminderCard()` → 被调试 Tab、本地逻辑直接调用
2. **Gateway invoke 命令**（远程智能体）：`card.reminder.update` → NodeInvokeDispatcher 路由 → 同样调用 `CardReminderService.updateReminderCard()`

两条路径最终汇聚到同一个函数，确保数据一致性。

### 4.3 跨进程数据传递

Form Kit 的卡片运行在独立进程（FormExtension），与主应用进程隔离。数据传递方式：

- **主 → 卡片**：`formProvider.updateForm(formId, formBindingData)` —— 主应用进程主动推送 JSON 数据到卡片进程
- **卡片 → 主应用**：卡片 UI 的 `onClick` 通过 `postCardAction` 发送路由/消息事件，主应用 `EntryAbility.onFormEvent` 接收

对于 `imageUrl`：**HarmonyOS NEXT Widget 卡片的 `Image()` 组件不支持直接加载 HTTP/HTTPS 网络 URL**（卡片运行在受限沙箱中）。正确的传递方式：
1. 主进程通过 `@kit.NetworkKit` 将图片下载到应用沙箱内的临时目录
2. 以只读模式打开文件，获取文件描述符 (fd)
3. 通过 `formBindingData` 的 `formImages` 字段传递 `{ imgKey: fd }`，Widget 中 `Image('imgKey')` 引用该 key

> **注意**：`formImages` 中传递的 fd 由 Form Kit 框架接管生命周期。调用 `updateForm` 后应立即关闭本端的 fd，避免泄漏。临时文件可在下次推送新图片前删除。

---

## 五、新增文件详细设计

### 5.1 `service/CardReminderService.ets` — 卡片数据管理服务

**定位**：卡片提醒数据的单一管理点。封装 `formProvider.updateForm()` 调用，管理已添加的 formId 列表，处理 invoke command 参数解析。

**目录路径**：`entry/src/main/ets/service/CardReminderService.ets`

```typescript
import { formProvider, formBindingData } from '@kit.FormKit';
import { InvokeRequest, InvokeResult } from '../api/GatewaySession';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** formImages 中图片资源的固定 key，Widget 端通过 Image('reminderImg') 引用 */
const FORM_IMAGE_KEY = 'reminderImg';

export class ReminderCardContent {
  title: string = '';
  body: string = '';
  note: string = '';
  imageUrl: string = '';
  style: string = '';   // 'infoShowTitleBodyNoteImage' | 'infoShowTitleImageAndImport'
}

export class CardReminderService {
  private formIds: string[] = [];
  private currentContent: ReminderCardContent;
  /** 当前已下载图片的本地路径，用于更新时清理旧资源 */
  private currentImagePath: string = '';

  constructor() {
    this.currentContent = new ReminderCardContent();
    this.currentContent.title = '';
    this.currentContent.body = '当前无主动提醒';
    this.currentContent.note = '';
    this.currentContent.imageUrl = '';
  }

  getCurrentContent(): ReminderCardContent {
    return this.currentContent;
  }

  addFormId(formId: string): void {
    const trimmed = formId.trim();
    if (trimmed.length === 0) return;
    if (this.formIds.indexOf(trimmed) < 0) {
      this.formIds.push(trimmed);
      console.info('CardReminderService: added formId=' + trimmed);
    }
  }

  removeFormId(formId: string): void {
    const trimmed = formId.trim();
    const index = this.formIds.indexOf(trimmed);
    if (index >= 0) {
      this.formIds.splice(index, 1);
      console.info('CardReminderService: removed formId=' + trimmed);
    }
  }

  pushCurrentToForm(formId: string): void {
    if (!formId || formId.trim().length === 0) return;
    this.buildAndPush(formId);
  }

  updateReminderCard(content: ReminderCardContent): void {
    this.currentContent = content;
    // 若内容不含图片 URL，清理旧文件
    if (content.imageUrl.length === 0) {
      this.cleanupImageFile();
      this.pushToAllForms();
      return;
    }
    // 先下载图片，再推送
    this.downloadAndPush();
  }

  resetToDefault(): void {
    const c = new ReminderCardContent();
    c.body = '当前无主动提醒';
    this.updateReminderCard(c);
  }

  handleUpdateReminderCommand(request: InvokeRequest): InvokeResult {
    const paramsJson = request.paramsJson.trim();
    if (paramsJson.length === 0) {
      return InvokeResult.error('INVALID_PARAMS', 'Missing paramsJson');
    }
    try {
      const parsed = JSON.parse(paramsJson) as Record<string, string>;
      const content = new ReminderCardContent();
      content.title = (parsed['title'] || '').trim();
      content.body = (parsed['body'] || '').trim();
      content.note = (parsed['note'] || '').trim();
      content.imageUrl = (parsed['imageUrl'] || '').trim();
      content.style = (parsed['style'] || '').trim();
      if (content.body.length === 0) {
        return InvokeResult.error('INVALID_PARAMS', 'body is required');
      }
      // style=infoShowTitleImageAndImport 时 imageUrl 也是必填
      if (content.style === 'infoShowTitleImageAndImport' && content.imageUrl.length === 0) {
        return InvokeResult.error('INVALID_PARAMS', 'imageUrl is required for style infoShowTitleImageAndImport');
      }
      this.updateReminderCard(content);
      return InvokeResult.ok(JSON.stringify({ ok: true, formIdsCount: this.formIds.length }));
    } catch (e) {
      return InvokeResult.error('INVALID_PARAMS', 'Failed to parse paramsJson');
    }
  }

  // ─── 图片处理 ───

  /** 下载图片到临时目录，返回本地路径。失败返回空字符串。 */
  private async downloadImage(url: string): Promise<string> {
    try {
      const httpReq = http.createHttp();
      const resp = await httpReq.request(url, { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.ARRAY_BUFFER });
      httpReq.destroy();
      if (resp.result instanceof ArrayBuffer && resp.result.byteLength > 0) {
        const buf = new Uint8Array(resp.result as ArrayBuffer);
        // 写入沙箱临时目录
        const ctx = AppStorage.get<Context>('abilityContext');
        const tmpDir = ctx ? ctx.tempDir : '/data/storage/el2/base/temp/';
        const fileName = 'reminder_img_' + Date.now() + '.cache';
        const filePath = tmpDir + '/' + fileName;
        const fd = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(fd, buf.buffer);
        fileIo.closeSync(fd);
        console.info('CardReminderService: downloaded image to ' + filePath + ', size=' + buf.length);
        return filePath;
      }
    } catch (e) {
      const be = e as BusinessError;
      console.error('CardReminderService: downloadImage failed: ' + be.message);
    }
    return '';
  }

  /** 删除旧图片文件，释放磁盘空间 */
  private cleanupImageFile(): void {
    if (this.currentImagePath.length === 0) return;
    try {
      fileIo.unlinkSync(this.currentImagePath);
      console.info('CardReminderService: cleaned up old image: ' + this.currentImagePath);
    } catch (e) {
      console.warn('CardReminderService: cleanupImageFile failed: ' + (e as Error).message);
    }
    this.currentImagePath = '';
  }

  /** 下载图片后推送到所有卡片 */
  private async downloadAndPush(): Promise<void> {
    const url = this.currentContent.imageUrl;
    if (url.length === 0) return;
    const localPath = await this.downloadImage(url);
    if (localPath.length > 0) {
      this.cleanupImageFile(); // 先清理旧图片
      this.currentImagePath = localPath;
    }
    this.pushToAllForms();
  }

  // ─── 推送 ───

  private buildAndPush(formId: string): void {
    const bindingData = this.buildFormBindingData();
    formProvider.updateForm(formId, bindingData)
      .then(() => console.info('CardReminderService: pushed to formId=' + formId))
      .catch((err: Error) => console.warn('CardReminderService: push failed ' + err.message));
  }

  private pushToAllForms(): void {
    if (this.formIds.length === 0) {
      console.info('CardReminderService: no formIds registered, skipping push');
      return;
    }
    const bindingData = this.buildFormBindingData();
    for (let i = 0; i < this.formIds.length; i++) {
      const formId = this.formIds[i];
      formProvider.updateForm(formId, bindingData)
        .then(() => console.info('CardReminderService: pushed to formId=' + formId))
        .catch((err: Error) => {
          if (err.message.includes('not found') || err.message.includes('deleted')) {
            this.formIds.splice(i, 1);
            i--;
          }
        });
    }
    // updateForm 调用完成后关闭 fd（Form Kit 框架已接管），但文件本身保留供后续推送
  }

  buildCurrentFormBindingData(): formBindingData.FormBindingData {
    return this.buildFormBindingData();
  }

  private buildFormBindingData(): formBindingData.FormBindingData {
    const hasImg = this.currentImagePath.length > 0;
    const data: Record<string, Object | string> = {
      'title': this.currentContent.title,
      'body': this.currentContent.body,
      'note': this.currentContent.note,
      'hasImage': hasImg ? 'true' : 'false',
      'style': this.currentContent.style.length > 0 ? this.currentContent.style : 'infoShowTitleBodyNoteImage'
    };

    if (hasImg) {
      // imgSrc 供 Widget 的 Image(imgSrc) 引用 formImages 中的 key
      data['imgSrc'] = FORM_IMAGE_KEY;
      // formImages：传递文件描述符给卡片进程
      const fd = fileIo.openSync(this.currentImagePath, fileIo.OpenMode.READ_ONLY);
      const formImages: Record<string, number> = {};
      formImages[FORM_IMAGE_KEY] = fd;
      data['formImages'] = formImages;
    }

    return formBindingData.createFormBindingData(data);
  }
}

export const cardReminderService = new CardReminderService();
```

**关键说明**：

1. **formId 管理**：卡片添加到桌面时系统分配 formId，通过 `ReminderFormExtension.onAddForm()` 回调收集。`updateForm()` 需要指定目标 formId，所以必须维护已添加卡片列表。
2. **默认内容**：构造函数中初始化为 "当前无主动提醒"（只有 body，title/note/imageUrl 为空）。
3. **双通道汇聚**：`handleUpdateReminderCommand()` 是 invoke 入口，`updateReminderCard()` 是本地 API 入口，两者最终都调用同一 `pushToAllForms()`。
4. **无效 formId 自动清理**：`updateForm()` 失败且错误包含 "not found/deleted/invalid" 时，自动从列表移除。
5. **图片下载 + formImages 传递**：
   - `downloadImage(url)` 使用 `@kit.NetworkKit` http 请求下载图片到沙箱临时目录
   - `buildFormBindingData()` 中若 `currentImagePath` 有效，以只读方式打开 fd，通过 `formImages: { reminderImg: fd }` 传递给卡片
   - 卡片 Widget 中 `Image('reminderImg')` 通过 key 引用该 fd
   - `downloadAndPush()` 在 `updateReminderCard` 有图片 URL 时异步执行下载→清理旧文件→推送
6. **资源清理**：`currentImagePath` 追踪当前图片路径。每次下载新图片前 `cleanupImageFile()` 删除旧临时文件。无图片时（resetToDefault 等）同样触发清理。

---

### 5.2 `form/ReminderFormExtension.ets` — FormExtension 生命周期

**定位**：Form Kit 要求的 ExtensionAbility 入口。管理卡片生命周期事件（添加、更新、删除）。

**目录路径**：`entry/src/main/ets/form/ReminderFormExtension.ets`

```typescript
import { FormExtension } from '@kit.FormKit';
import { formInfo } from '@kit.AbilityKit';
import { cardReminderService } from '../service/CardReminderService';

export default class ReminderFormExtension extends FormExtension {
  onAddForm(want: formInfo.Want): string {
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string || '';
    console.info('ReminderFormExtension: onAddForm, formId=' + formId);
    cardReminderService.addFormId(formId);
    // 立即推送当前内容到新添加的卡片，确保新卡片不是空白状态
    cardReminderService.pushCurrentToForm(formId);
    return formId;
  }

  onUpdateForm(formId: string): void {
    console.info('ReminderFormExtension: onUpdateForm, formId=' + formId);
  }

  onRemoveForm(formId: string): void {
    console.info('ReminderFormExtension: onRemoveForm, formId=' + formId);
    cardReminderService.removeFormId(formId);
  }

  onFormEvent(formId: string, message: string): void {
    console.info('ReminderFormExtension: onFormEvent, formId=' + formId + ', message=' + message);
  }

  onDestroy(): void {
    console.info('ReminderFormExtension: onDestroy');
  }
}
```

**关键说明**：

1. **onAddForm**：用户从桌面添加卡片时触发。系统分配 formId 通过 `want.parameters['ohos.extra.param.key.form_identity']` 传递。收集后存入 `cardReminderService`，然后立即调用 `pushCurrentToForm(formId)` 将当前内容推送到新卡片，确保新卡片不会显示空白/过期内容。
2. **onRemoveForm**：用户从桌面移除卡片时触发。清理 formId，避免后续 `updateForm()` 调用失败。
3. **onUpdateForm**：系统定时刷新触发（配置中 `updateDuration` > 0 时）。当前不做额外操作，因为主动推送覆盖了所有数据更新场景。
4. **onFormEvent**：卡片 UI 中 `postCardAction` 发出的消息事件。当前仅打日志，后续可扩展为跳转到主应用特定页面。
5. **跨进程访问说明**：HarmonyOS FormExtension 默认运行在宿主应用进程内，ETS 模块缓存是进程级共享的。因此 `ReminderFormExtension` 中导入 `cardReminderService` 单例能正确访问主应用创建的同个实例。这是 HarmonyOS Form Kit 的默认行为，不需要额外配置。

---

### 5.3 `widget/pages/ReminderCardWidget.ets` — 卡片 UI（双风格）

**定位**：ArkTS 卡片声明式 UI。通过 `style` 字段在两种渲染模式间切换。

**目录路径**：`entry/src/main/ets/widget/pages/ReminderCardWidget.ets`

**卡片支持尺寸**：2×2（标准小卡片）和 2×4（横宽卡片）。

```typescript
let storage = new LocalStorage();

@Entry(storage)
@Component
struct ReminderCardWidget {
  @LocalStorageProp('title') title: string = '';
  @LocalStorageProp('body') body: string = '当前无主动提醒';
  @LocalStorageProp('note') note: string = '';
  @LocalStorageProp('imgSrc') imgSrc: string = '';
  @LocalStorageProp('hasImage') hasImageStr: string = 'false';
  @LocalStorageProp('style') style: string = 'infoShowTitleBodyNoteImage';

  build() {
    if (this.style === 'infoShowTitleImageAndImport') {
      this.ImageImportLayout();
    } else {
      this.InfoShowLayout();
    }
  }

  // ── 风格 A: infoShowTitleBodyNoteImage（信息展示卡，默认）──
  @Builder InfoShowLayout() {
    Row() {
      Column() {
        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(14).fontWeight(400).fontColor('#99000000')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 10 });
        }

        Text(this.body)
          .fontSize(17).fontWeight(500).fontColor('#E5000000')
          .maxLines(3).lineHeight(22)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (this.note.length > 0) {
          Text(this.note)
            .fontSize(14).fontWeight(400).fontColor('#99000000')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 10 });
        }
      }
      .layoutWeight(this.hasImageStr === 'true' ? 1 : 0)
      .width(this.hasImageStr === 'true' ? undefined : '100%')
      .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
      .padding({ left: 14, right: this.hasImageStr === 'true' ? 10 : 14, top: 14, bottom: 14 });

      if (this.hasImageStr === 'true') {
        Image('memory://' + this.imgSrc)
          .width(132).height(120)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .margin({ right: 14 })
          .alt($r('app.media.icon'));
      }
    }
    .alignItems(VerticalAlign.Center)
    .width('100%').height('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        action: 'router', abilityName: 'EntryAbility',
        params: { targetPage: 'import' }
      });
    });
  }

  // ── 风格 B: infoShowTitleImageAndImport（图片导入卡）──
  @Builder ImageImportLayout() {
    Stack() {
      // 底层：全幅背景图
      if (this.hasImageStr === 'true') {
        Image('memory://' + this.imgSrc)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(16)
          .alt($r('app.media.icon'));
      }

      // 上层：右侧两个半透明操作按钮（Stack + Row + Blank 定位，安全兼容 Form 组件限制）
      Row() {
        Blank()
        Column({ space: 8 }) {
          // "拍一拍" 按钮 → 跳转到导入页并自动触发拍照
          Column() {
            Text('拍一拍')
              .fontSize(11).fontWeight(FontWeight.Medium).fontColor('#1D5DD8')
          }
          .width(48).height(48)
          .borderRadius(12)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('rgba(236,243,255,0.70)')
          .border({ width: 1, color: 'rgba(213,226,250,0.70)' })
          .onClick(() => {
            postCardAction(this, {
              action: 'router', abilityName: 'EntryAbility',
              params: { targetPage: 'import', importAction: 'camera' }
            });
          });

          // "选一选" 按钮 → 跳转到导入页并自动触发相册
          Column() {
            Text('选一选')
              .fontSize(11).fontWeight(FontWeight.Medium).fontColor('#1D5DD8')
          }
          .width(48).height(48)
          .borderRadius(12)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('rgba(236,243,255,0.70)')
          .border({ width: 1, color: 'rgba(213,226,250,0.70)' })
          .onClick(() => {
            postCardAction(this, {
              action: 'router', abilityName: 'EntryAbility',
              params: { targetPage: 'import', importAction: 'gallery' }
            });
          });
        }
        .margin({ right: 14 })
      }
      .width('100%').height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%').height('100%')
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        action: 'router', abilityName: 'EntryAbility',
        params: { targetPage: 'import' }
      });
    });
  }
}
```

**关键设计解析**：

1. **风格切换**：`build()` 中根据 `this.style` 值选择渲染 `InfoShowLayout()` 或 `ImageImportLayout()`。`style` 不传或为未知值时走默认的 `InfoShowLayout`。

2. **InfoShowLayout（信息展示卡）**：
   - **左右分栏**：使用 `Row` 作为顶层容器。文字区 `Column` 在左，可选 `Image` 在右。
   - **无图时文字扩展**：当 `hasImageStr === 'false'`：文字区 `layoutWeight(0)` + `width('100%')` → 占满整行，正文最多 3 行。右侧 `Image` 不渲染。
   - **有图时文字压缩**：当 `hasImageStr === 'true'`：文字区 `layoutWeight(1)` 自适应，右侧 `Image` 占 132×120vp。正文最多 3 行。
   - **标题行可选**：`if (this.title.length > 0)` 控制。默认内容没有标题，只显示 body。
   - **备注行可选**：`if (this.note.length > 0)` 控制。无备注时不占空间。
   - **备注行可选**：`if (this.note.length > 0)` 控制第三行是否渲染。无备注时不占空间。
   - **点击跳转**：整卡点击路由到 `EntryAbility`，传递 `targetPage: 'import'`。

3. **ImageImportLayout（图片导入卡）**：
   - **全幅背景图**：`Image` 占满卡片 100% 宽高，`ImageFit.Cover` 填充，圆角 16vp 跟随卡片圆角。
   - **半透明按钮**：右侧垂直居中排列两个 48×48vp 正方形按钮，间距 8vp。背景 `rgba(236,243,255,0.70)` 半透明浅蓝，边框 `rgba(213,226,250,0.70)`，与 ImportPage 的拍照/相册按钮颜色同源。按钮间距卡片右边缘 14vp。
   - **"拍一拍" 按钮**：点击路由到 `EntryAbility`，携带 `importAction: 'camera'` 参数。ImportPage 收到后自动触发拍照导入。
   - **"选一选" 按钮**：点击路由到 `EntryAbility`，携带 `importAction: 'gallery'` 参数。ImportPage 收到后自动触发相册导入。
   - **整卡点击**：点击背景图区域路由到 `EntryAbility`，传递 `targetPage: 'import'`（无 importAction，仅跳转）。

4. **图片传递机制**：Widget 卡片不支持直接加载 HTTP URL。CardReminderService 先将图片下载到沙箱临时目录，然后通过 `formBindingData` 的 `formImages: { reminderImg: fd }` 以文件描述符形式传递给卡片进程。卡片中 `Image('memory://' + this.imgSrc)` 通过 key 引用该 fd。`alt($r('app.media.icon'))` 作为下载失败/无图片时的兜底图标。

5. **资源清理**：`CardReminderService` 通过 `currentImagePath` 追踪当前图片路径。每次推送新图片前调用 `cleanupImageFile()` 删除旧文件。`updateForm` 调用完成后 Form Kit 框架接管 fd 生命周期。

6. **为什么用字符串判断风格？** ArkTS 卡片受限环境中不支持复杂类型，`style` 作为字符串通过 LocalStorage 传递，与现有的 `hasImage` 布尔字符串模式一致，是 HarmonyOS 官方推荐的实践。

---

### 5.4 `pages/DebugPage.ets` — 调试 Tab 页面

**定位**：开发调试用的 Tab 页面。提供手动推送卡片内容、模拟 invoke command、查看当前卡片状态等功能。

**目录路径**：`entry/src/main/ets/pages/DebugPage.ets`

```typescript
import { MainViewModel } from '../viewmodel/MainViewModel';
import { InvokeRequest } from '../api/GatewaySession';
import { ReminderCardContent, cardReminderService } from '../service/CardReminderService';

@Component
export struct DebugPage {
  @ObjectLink viewModel: MainViewModel;
  @StorageProp('localeVersion') localeVersion: number = 0;

  @State debugTitle: string = '';
  @State debugBody: string = '';
  @State debugNote: string = '';
  @State debugImageUrl: string = '';
  @State pushResult: string = '';
  @State currentCardState: string = '';

  aboutToAppear(): void {
    this.refreshCurrentCardState();
  }

  aboutToDisappear(): void {
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.Header();
        this.CardPreviewSection();
        this.PushFormSection();
        this.InvokeSimulateSection();
        this.CardStateSection();

        if (this.pushResult.length > 0) {
          this.PushResultRail();
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 24 });
    }
    .width('100%')
    .height('100%');
  }

  @Builder Header() {
    Column({ space: 6 }) {
      Text(this.localizedText('debug_header_eyebrow', 'DEBUG'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Text(this.localizedText('debug_header_title', 'Debug'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#17181C');

      Text(this.localizedText('debug_header_subtitle', 'Test card content, simulate invoke commands, and inspect device state.'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#4D5563');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder CardPreviewSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_card_preview_label', 'CARD PREVIEW'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column() {
        Row() {
          Column() {
            if (this.currentCardContent().title.length > 0) {
              Text(this.currentCardContent().title)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#17181C')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }

            Text(this.currentCardContent().body)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#4D5563')
              .maxLines(this.currentCardContent().imageUrl.length > 0 ? 3 : 5)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            if (this.currentCardContent().note.length > 0) {
              Text(this.currentCardContent().note)
                .fontSize(10)
                .fontWeight(FontWeight.Normal)
                .fontColor('#8A92A2')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
          }
          .layoutWeight(this.currentCardContent().imageUrl.length > 0 ? 1 : 0)
          .width(this.currentCardContent().imageUrl.length > 0 ? '60%' : '100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 14, right: 4, top: 14, bottom: 14 });

          if (this.currentCardContent().imageUrl.length > 0) {
            Image(this.currentCardContent().imageUrl)
              .width('38%')
              .height(120)
              .objectFit(ImageFit.Cover)
              .borderRadius(8)
              .alt($r('app.media.icon'));
          }
        }
        .width('100%');
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder PushFormSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_push_label', 'PUSH CARD CONTENT'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column({ space: 10 }) {
        TextInput({ placeholder: this.localizedText('debug_push_title_placeholder', 'Title (optional)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugTitle = value;
          });

        TextInput({ placeholder: this.localizedText('debug_push_body_placeholder', 'Body (required)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugBody = value;
          });

        TextInput({ placeholder: this.localizedText('debug_push_note_placeholder', 'Note (optional)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugNote = value;
          });

        TextInput({ placeholder: this.localizedText('debug_push_image_placeholder', 'Image URL (optional)') })
          .fontSize(14)
          .onChange((value: string) => {
            this.debugImageUrl = value;
          });

        Row({ space: 12 }) {
          Button(this.localizedText('debug_push_button', 'Push to Card'))
            .type(ButtonType.Normal)
            .backgroundColor('#C8841A')
            .fontColor('#FFFFFF')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .borderRadius(12)
            .onClick(() => {
              this.handlePushToCard();
            });

          Button(this.localizedText('debug_reset_button', 'Reset Default'))
            .type(ButtonType.Normal)
            .backgroundColor('#F6F7FA')
            .fontColor('#8A92A2')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .borderRadius(12)
            .border({ width: 1, color: '#E5E7EC' })
            .onClick(() => {
              this.handleResetDefault();
            });
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder InvokeSimulateSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_invoke_label', 'INVOKE SIMULATION'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column({ space: 10 }) {
        Text(this.localizedText('debug_invoke_desc', 'Simulates a gateway invoke command (card.reminder.update) using the current form fields above.'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4D5563');

        Button(this.localizedText('debug_invoke_button', 'Simulate Invoke'))
          .type(ButtonType.Normal)
          .backgroundColor('#1D5DD8')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .borderRadius(12)
          .onClick(() => {
            this.handleSimulateInvoke();
          });
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder CardStateSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('debug_state_label', 'CARD STATE'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C8841A');

      Column({ space: 8 }) {
        this.InfoRow('formIds count', String(cardReminderService.getCurrentContent().body.length > 0 ? 'has content' : 'empty'));
        this.InfoRow(this.localizedText('debug_state_title', 'Title'), this.currentCardContent().title || '(empty)');
        this.InfoRow(this.localizedText('debug_state_body', 'Body'), this.currentCardContent().body);
        this.InfoRow(this.localizedText('debug_state_note', 'Note'), this.currentCardContent().note || '(empty)');
        this.InfoRow(this.localizedText('debug_state_image', 'Image URL'), this.currentCardContent().imageUrl || '(empty)');
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: '#E5E7EC' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder PushResultRail() {
    Column({ space: 2 }) {
      Text(this.localizedText('debug_result_label', 'PUSH RESULT'))
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#C8841A');

      Text(this.pushResult)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#17181C');
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#C8841A' });
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#17181C');

      Blank();

      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8A92A2')
        .maxLines(2)
        .textAlign(TextAlign.End);
    }
    .width('100%');
  }

  private currentCardContent(): ReminderCardContent {
    return cardReminderService.getCurrentContent();
  }

  private refreshCurrentCardState(): void {
    const content = cardReminderService.getCurrentContent();
    this.currentCardState = JSON.stringify({
      title: content.title,
      body: content.body,
      note: content.note,
      imageUrl: content.imageUrl
    });
  }

  private handlePushToCard(): void {
    if (this.debugBody.trim().length === 0) {
      this.pushResult = 'Error: body is required.';
      return;
    }

    const content = new ReminderCardContent();
    content.title = this.debugTitle.trim();
    content.body = this.debugBody.trim();
    content.note = this.debugNote.trim();
    content.imageUrl = this.debugImageUrl.trim();

    cardReminderService.updateReminderCard(content);
    this.refreshCurrentCardState();
    this.pushResult = 'Pushed: title="' + content.title + '", body="' + content.body + '"';
  }

  private handleResetDefault(): void {
    cardReminderService.resetToDefault();
    this.refreshCurrentCardState();
    this.debugTitle = '';
    this.debugBody = '';
    this.debugNote = '';
    this.debugImageUrl = '';
    this.pushResult = 'Reset to default.';
  }

  private handleSimulateInvoke(): void {
    if (this.debugBody.trim().length === 0) {
      this.pushResult = 'Error: body is required for invoke.';
      return;
    }

    const paramsJson = JSON.stringify({
      title: this.debugTitle.trim(),
      body: this.debugBody.trim(),
      note: this.debugNote.trim(),
      imageUrl: this.debugImageUrl.trim()
    });

    const request = new InvokeRequest();
    request.id = 'debug-simulate';
    request.nodeId = 'debug-node';
    request.command = 'card.reminder.update';
    request.paramsJson = paramsJson;

    const result = cardReminderService.handleUpdateReminderCommand(request);
    this.refreshCurrentCardState();
    this.pushResult = 'Invoke result: ok=' + result.ok + (result.error ? ', error=' + result.error.message : '');
  }

  private localizedText(name: string, fallback: string): string {
    try {
      void this.localeVersion;
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (error) {
      console.warn('DebugPage: localizedText failed for key: ' + name);
      return fallback;
    }
  }
}
```

**设计要点**：

1. **调试颜色系**：使用 `#C8841A`（琥珀色/Warning 色），与现有 5 色体系中的 Warning 色一致，但只用于调试 Tab 的 eyebrow 和标签，区别于其他 Tab 的蓝色主调。视觉上明确标识"这是调试/开发功能"。

2. **卡片预览区**：完全复刻卡片 UI 的左右分栏逻辑，在主应用内渲染一个等比例预览，方便开发者在不用真机桌面的情况下验证布局效果。

3. **Push to Card**：直接调用 `cardReminderService.updateReminderCard()`，验证本地 API 通道。

4. **Simulate Invoke**：构造 `InvokeRequest` 对象，调用 `cardReminderService.handleUpdateReminderCommand()`，验证 Gateway invoke 通道的参数解析和错误处理。不经过 WebSocket，纯本地模拟。

5. **Card State**：实时显示 `cardReminderService.getCurrentContent()` 的当前值，方便调试数据传递链路。

6. **formId 信息**：后续可扩展显示 `cardReminderService` 内部 formId 列表，当前只显示内容状态。

---

## 六、现有文件修改设计

### 6.1 `module.json5` — 新增 FormExtension + 配置引用

```diff
 {
   "module": {
     "name": "entry",
     "type": "entry",
     "description": "$string:module_desc",
     "mainElement": "EntryAbility",
     "deviceTypes": [
       "phone",
       "tablet"
     ],
     "deliveryWithInstall": true,
     "installationFree": false,
     "pages": "$profile:main_pages",
     "abilities": [
       {
         "name": "EntryAbility",
         ...existing...
       }
-    ],
+    },
+    {
+      "name": "ReminderFormExtension",
+      "srcEntry": "./ets/form/ReminderFormExtension.ets",
+      "description": "$string:reminder_form_desc",
+      "icon": "$media:icon",
+      "label": "$string:reminder_form_label",
+      "type": "form",
+      "formConfig": "$profile:form_config",
+      "exported": true
+    }
+    ],
     "requestPermissions": [
       ...existing...
     ]
   }
 }
```

**关键说明**：

1. **type: "form"** — 这是 Form Kit 的 ExtensionAbility 类型标识。
2. **formConfig: "$profile:form_config"** — 引用 `resources/base/profile/form_config.json`，定义卡片尺寸规格和刷新策略。
3. **icon/label** — 卡片在桌面卡片市场展示时使用的图标和名称。
4. **exported: true** — 卡片必须 exported，否则系统无法发现和添加。

### 6.2 `resources/base/profile/form_config.json` — 卡片配置

```json
{
  "forms": [
    {
      "name": "ReminderCard",
      "displayName": "$string:reminder_form_display_name",
      "description": "$string:reminder_form_desc",
      "src": "./ets/form/pages/ReminderCardWidget.ets",
      "uiSyntax": "arkts",
      "window": {
        "designWidth": 720,
        "autoDesignWidth": true
      },
      "colorMode": "auto",
      "isDefault": true,
      "updateDuration": 1,
      "defaultDimension": "2*4",
      "supportDimensions": [
        "2*2",
        "2*4"
      ],
      "formConfigAbility": ""
    }
  ]
}
```

**关键说明**：

1. **uiSyntax: "arkts"** — 使用 ArkTS 声明式卡片，而非 JS 卡片。
2. **updateDuration: 1** — 定时刷新周期为 1 个单位（约 1 小时），作为兜底刷新。主动推送不受此限制。
3. **defaultDimension: "2*4"** — 默认添加尺寸为 2*4。
4. **supportDimensions** — 支持 2×2 和 2×4，用户可以在添加时选择尺寸，2*2时不显示图片。
5. **src** — 卡片 UI 文件路径。

### 6.3 `PostOnboardingTabs.ets` — 3处增量修改

**修改 1：顶部 import 区**

```diff
  import { ImportPage } from './ImportPage';
+ import { DebugPage } from './DebugPage';
```

**修改 2：条件渲染区**

```diff
        } else if (this.activeTab === 5) {
          ImportPage({ viewModel: this.viewModel });
+       } else if (this.activeTab === 6) {
+         DebugPage({ viewModel: this.viewModel });
        }
```

**修改 3：TabBar Builder 中新增 TabItem**

```diff
      this.TabItem(5, this.localizedText('tab_import', 'Import'), '📥');
+     this.TabItem(6, this.localizedText('tab_debug', 'Debug'), '🔧');
```

**说明**：与 Import Tab 的添加模式完全一致。Debug = index=6，使用显式 `else if (this.activeTab === 6)` 精确匹配。不使用 `else` 兜底，避免 `activeTab` 意外越界时静默渲染错误页面。

### 6.4 `OpenClawProtocolConstants.ets` — 新增 Card Command enum

```diff
  export enum OpenClawCallLogCommand {
    Search = 'callLog.search'
- }
+ }

+ export enum OpenClawCardCommand {
+   ReminderUpdate = 'card.reminder.update'
+ }
```

### 6.5 `InvokeCommandRegistry.ets` — 新增 card command spec

```diff
  import { OpenClawCapability, OpenClawDeviceCommand } from '../protocol/OpenClawProtocolConstants';
+ import { OpenClawCardCommand } from '../protocol/OpenClawProtocolConstants';

  export class HarmonyNodeRuntimeFlags {
    deviceInfoAvailable: boolean = true;
+   cardReminderAvailable: boolean = true;
  }

  export class InvokeCommandRegistry {
    static readonly all: InvokeCommandSpec[] = [
      new InvokeCommandSpec(OpenClawDeviceCommand.Status),
      new InvokeCommandSpec(OpenClawDeviceCommand.Info),
      new InvokeCommandSpec(OpenClawDeviceCommand.Permissions),
+     new InvokeCommandSpec(OpenClawCardCommand.ReminderUpdate),
      new InvokeCommandSpec(OpenClawDeviceCommand.Health)
    ];

    ...

    static advertisedCapabilities(flags: HarmonyNodeRuntimeFlags): string[] {
      const caps: string[] = [];
      if (flags.deviceInfoAvailable) {
        caps.push(OpenClawCapability.Device);
      }
+     if (flags.cardReminderAvailable) {
+       caps.push(OpenClawCapability.Card);
+     }
      return caps;
    }

    static advertisedCommands(flags: HarmonyNodeRuntimeFlags): string[] {
      const commands: string[] = [];
      if (flags.deviceInfoAvailable) {
        ...existing...
      }
+     if (flags.cardReminderAvailable) {
+       commands.push(OpenClawCardCommand.ReminderUpdate);
+     }
      return commands;
    }
  }
```

**说明**：新增 `OpenClawCapability.Card = 'card'` 和 `OpenClawCardCommand.ReminderUpdate`。与现有 `Device`/`Canvas` 等能力注册模式完全一致。

### 6.6 `OpenClawProtocolConstants.ets` — 新增 Capability 和 Command enum 条目

```diff
  export enum OpenClawCapability {
    Canvas = 'canvas',
    Camera = 'camera',
+   Card = 'card',
    ...existing...
  }
```

### 6.7 `NodeInvokeDispatcher.ets` — 新增 card command 处理分支

```diff
  import { InvokeRequest, InvokeResult } from '../api/GatewaySession';
  import {
    OpenClawCanvasCommand,
-   OpenClawDeviceCommand
+   OpenClawDeviceCommand,
+   OpenClawCardCommand
  } from '../protocol/OpenClawProtocolConstants';
+ import { cardReminderService } from '../service/CardReminderService';

  ...in handleInvoke switch:

      case OpenClawDeviceCommand.Health:
        return InvokeResult.ok(this.buildDeviceHealthPayload());
+     case OpenClawCardCommand.ReminderUpdate:
+       return this.handleCardReminderUpdate(request);
      default:
        return InvokeResult.error('INVALID_REQUEST', 'INVALID_REQUEST: unknown command');
  }

+ private handleCardReminderUpdate(request: InvokeRequest): InvokeResult {
+   return cardReminderService.handleUpdateReminderCommand(request);
+ }
```

**说明**：invoke command 的处理逻辑封装在 `CardReminderService` 中，NodeInvokeDispatcher 只做路由转发，保持与现有 canvas/device command 处理的架构一致性。

### 6.8 `EntryAbility.ets` — onFormEvent / onNewWant 处理卡片路由

```diff
  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
    this.bumpLocaleVersion();
    mainViewModel.refreshLocalizedUiState();
  }

+ onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
+   hilog.info(DOMAIN, TAG, 'onNewWant');
+   const targetPage = want.parameters?.['targetPage'] as string || '';
+   const importAction = want.parameters?.['importAction'] as string || '';
+   if (targetPage === 'import') {
+     // 传递到 AppStorage，PostOnboardingTabs 读取后切换到 import tab
+     AppStorage.setOrCreate<string>('pendingTargetTab', 'import');
+     if (importAction.length > 0) {
+       // 传递导入动作给 ImportPage：'camera' 或 'gallery'
+       AppStorage.setOrCreate<string>('pendingImportAction', importAction);
+     }
+   }
+ }
```

**说明**：
1. **卡片点击路由**：桌面卡片中的 `postCardAction` router 事件会触发 `EntryAbility.onNewWant()`（非 `onFormEvent`）。当 Want 参数包含 `targetPage: 'import'` 时，通过 AppStorage 传递目标 Tab 给 `PostOnboardingTabs`。
2. **导入动作转发（事件通道）**：采用 `importActionSeq`（自增序号）+ `pendingImportAction`（动作类型）双字段模式：
   - EntryAbility 每次收到卡片按钮点击时递增 `importActionSeq` 并写入 `pendingImportAction`
   - ImportPage 通过 `@StorageLink('importActionSeq') @Watch('onImportTrigger')` 监听序号变化
   - 自增序号保证每次点击都是唯一事件，即使连续两次点击同一按钮也能正确响应
   - **不依赖** `aboutToAppear` 生命周期 mount/unmount 时序
3. **ImportPage 响应逻辑**：
```typescript
// ImportPage — @StorageLink + @Watch 响应式事件监听
@StorageLink('importActionSeq') @Watch('onImportTrigger') importActionSeq: number = 0;

private onImportTrigger(): void {
  if (this.importActionSeq <= 0) return;  // 跳过初始空同步
  const action = AppStorage.get<string>('pendingImportAction') || '';
  if (action === 'camera') this.handleCapturePhoto();
  else if (action === 'gallery') this.handlePickFromAlbum();
}
```
4. **EntryAbility 事件生产**：
```typescript
// EntryAbility.applyTargetTab()
if (importAction.length > 0) {
  const seq = (AppStorage.get<number>('importActionSeq') ?? 0) + 1;
  AppStorage.setOrCreate<number>('importActionSeq', seq);      // 递增序号 → 触发 @Watch
  AppStorage.setOrCreate<string>('pendingImportAction', importAction); // 动作类型
}
```

---

## 七、国际化 Key 新增清单

### 7.1 `resources/base/element/string.json`

```json
    { "name": "tab_debug", "value": "Debug" },
    { "name": "debug_header_eyebrow", "value": "DEBUG" },
    { "name": "debug_header_title", "value": "Debug" },
    { "name": "debug_header_subtitle", "value": "Test card content, simulate invoke commands, and inspect device state." },
    { "name": "debug_card_preview_label", "value": "CARD PREVIEW" },
    { "name": "debug_push_label", "value": "PUSH CARD CONTENT" },
    { "name": "debug_push_title_placeholder", "value": "Title (optional)" },
    { "name": "debug_push_body_placeholder", "value": "Body (required)" },
    { "name": "debug_push_note_placeholder", "value": "Note (optional)" },
    { "name": "debug_push_image_placeholder", "value": "Image URL (optional)" },
    { "name": "debug_push_button", "value": "Push to Card" },
    { "name": "debug_reset_button", "value": "Reset Default" },
    { "name": "debug_invoke_label", "value": "INVOKE SIMULATION" },
    { "name": "debug_invoke_desc", "value": "Simulates a gateway invoke command (card.reminder.update) using the current form fields above." },
    { "name": "debug_invoke_button", "value": "Simulate Invoke" },
    { "name": "debug_state_label", "value": "CARD STATE" },
    { "name": "debug_state_title", "value": "Title" },
    { "name": "debug_state_body", "value": "Body" },
    { "name": "debug_state_note", "value": "Note" },
    { "name": "debug_state_image", "value": "Image URL" },
    { "name": "debug_result_label", "value": "PUSH RESULT" },
    { "name": "reminder_form_desc", "value": "Reminder card for OpenClaw" },
    { "name": "reminder_form_label", "value": "OpenClaw Reminder" },
    { "name": "reminder_form_display_name", "value": "Reminder" }
```

### 7.2 `resources/zh_CN/element/string.json`

```json
    { "name": "tab_debug", "value": "调试" },
    { "name": "debug_header_eyebrow", "value": "调试" },
    { "name": "debug_header_title", "value": "调试" },
    { "name": "debug_header_subtitle", "value": "测试卡片内容推送、模拟 invoke 命令、查看设备状态。" },
    { "name": "debug_card_preview_label", "value": "卡片预览" },
    { "name": "debug_push_label", "value": "推送卡片内容" },
    { "name": "debug_push_title_placeholder", "value": "标题（可选）" },
    { "name": "debug_push_body_placeholder", "value": "正文（必填）" },
    { "name": "debug_push_note_placeholder", "value": "备注（可选）" },
    { "name": "debug_push_image_placeholder", "value": "图片 URL（可选）" },
    { "name": "debug_push_button", "value": "推送到卡片" },
    { "name": "debug_reset_button", "value": "恢复默认" },
    { "name": "debug_invoke_label", "value": "INVOKE 模拟" },
    { "name": "debug_invoke_desc", "value": "使用上方表单字段模拟网关 invoke 命令（card.reminder.update）。" },
    { "name": "debug_invoke_button", "value": "模拟 Invoke" },
    { "name": "debug_state_label", "value": "卡片状态" },
    { "name": "debug_state_title", "value": "标题" },
    { "name": "debug_state_body", "value": "正文" },
    { "name": "debug_state_note", "value": "备注" },
    { "name": "debug_state_image", "value": "图片 URL" },
    { "name": "debug_result_label", "value": "推送结果" },
    { "name": "reminder_form_desc", "value": "OpenClaw 提醒卡片" },
    { "name": "reminder_form_label", "value": "OpenClaw 提醒" },
    { "name": "reminder_form_display_name", "value": "提醒" }
```

### 7.3 `resources/en_US/element/string.json`

与 base 相同，逐条复制即可。

---

## 八、架构一致性验证

| 维度 | 现有模式 | 新增是否遵循 |
|------|----------|-------------|
| 装饰器 | `@Component` + `@ObjectLink viewModel` + `@StorageProp localeVersion` | ✅ DebugPage 遵循 |
| 单例服务 | `securePrefs` / `mainViewModel` / `photoCaptureService` | ✅ `cardReminderService` 单例导出 |
| Invoke 路由 | `InvokeCommandRegistry.spec` → `NodeInvokeDispatcher.switch` → handler | ✅ `card.reminder.update` 同模式 |
| 能力广播 | `advertisedCapabilities` + `advertisedCommands` | ✅ 新增 `Card` capability 和 command |
| 条件渲染 Tab | `if (activeTab === N)` 显式精确匹配 | ✅ Debug = index=6，显式 `else if` |
| 国际化 | `localizedText(name, fallback)` + `@StorageProp localeVersion` | ✅ |
| Form Kit 模式 | FormExtension + formProvider + ArkTS 卡片 | ✅ 遵循官方规范 |
| 卡片尺寸 | 2×2/2×4 标准尺寸 | ✅ |
| 卡片风格切换 | `style` 字符串字段通过 formBindingData 传递，Widget 条件渲染 | ✅ 新增 `infoShowTitleImageAndImport` 风格 |
| 卡片→主应用路由 | `postCardAction` router → `EntryAbility.onNewWant` → AppStorage | ✅ `targetPage` + `importAction` 双参数 |

---

## 九、invoke command 规格定义

### 9.1 `card.reminder.update` — 智能体可调用的 Tool

**Command 名称**：`card.reminder.update`

**参数 JSON 结构**：

```json
{
  "style": "infoShowTitleBodyNoteImage",  // 可选，卡片风格（不传时默认识别）
  "title": "会议提醒",          // 可选，标题行（infoShowTitleImageAndImport 风格下忽略）
  "body": "下午 3:00 产品评审会议，会议室 A304",  // 必填，正文行
  "note": "请提前准备演示材料",   // 可选，备注行（infoShowTitleImageAndImport 风格下忽略）
  "imageUrl": "https://example.com/chart.png",  // 可选。有图时根据 style 做不同渲染；infoShowTitleImageAndImport 下无图时只显示 body 文字（上部左对齐）
  "skill": "数据录入"             // 可选，拍照/选图后发送给 chat 的技能指令。空则默认 '/ImageData'
}
```

**`style` 参数说明**：

| style 值 | 卡片行为 |
|----------|---------|
| `infoShowTitleBodyNoteImage` | 默认风格。左文字(title+body+note) + 右缩略图(imageUrl 可选) |
| `infoShowTitleImageAndImport` | 图片导入风格。全幅背景图(body 必填 + imageUrl 必填)，右侧两个半透明按钮引导拍照/选图 |
| 不传或未知值 | 按默认 `infoShowTitleBodyNoteImage` 处理 |

**返回 JSON 结构**（成功）：

```json
{
  "ok": true,
  "formIdsCount": 2
}
```

**返回 JSON 结构**（失败）：

```json
{
  "ok": false,
  "error": {
    "code": "INVALID_PARAMS",
    "message": "body is required for card.reminder.update"
  }
}
```

**验证规则**：
- `body` 必填，不可为空字符串
- `style` 可选，有效值为 `infoShowTitleBodyNoteImage`、`infoShowTitleImageAndImport`
- `style` 为 `infoShowTitleImageAndImport` 时：有 `imageUrl` 则全幅铺满+右侧按钮，无 `imageUrl` 则只显示 body 文字（上部左对齐）
- `title`、`note` 在 `infoShowTitleBodyNoteImage` 风格下可选，在 `infoShowTitleImageAndImport` 风格下忽略
- `imageUrl` 若提供必须是合法的 HTTP/HTTPS URL
- `skill` 可选，任意字符串。不参与卡片渲染，存入 AppStorage(`cardSkill`)。拍/选后发送 chat 时使用
- 所有字段最大长度：title 50 字符，body 200 字符，note 80 字符，skill 100 字符

**`skill` 参数说明**：

| skill 值 | 拍/选图片后发送的 chat 文本 |
|----------|--------------------------|
| 空 / 不传 | `/ImageData`（默认行为） |
| `"数据录入"` | `/skill 数据录入` |
| `"健康记录"` | `/skill 健康记录` |

**数据流**：`card.reminder.update { skill } → CardReminderService → AppStorage('cardSkill') → PhotoCaptureService.obtainPhotoToProcess() → sendChat(msgText)`

### 9.2 智能体调用示例

从 Gateway 侧来看，AI 智能体调用此 Tool 的流程：

```
智能体 → Gateway → node.invoke.request
{
  "command": "card.reminder.update",
  "paramsJson": "{\"title\":\"快递提醒\",\"body\":\"您的快递已到达楼下快递柜\",\"note\":\"取件码: 8-2-5678\",\"imageUrl\":\"\"}"
}
→ HarmonyOS NodeSession 接收
→ NodeInvokeDispatcher 路由到 CardReminderService.handleUpdateReminderCommand()
→ 更新 CardReminderService.currentContent
→ formProvider.updateForm() 推送到桌面卡片
→ 卡片 UI 渲染新内容
→ 返回 InvokeResult.ok({"ok":true,"formIdsCount":1})
→ Gateway → 智能体收到成功响应
```

**style=infoShowTitleImageAndImport 调用示例**：

```
智能体 → Gateway → node.invoke.request
{
  "command": "card.reminder.update",
  "paramsJson": "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"今天的健康餐推荐\",\"imageUrl\":\"https://example.com/meal.jpg\"}"
}
→ HarmonyOS NodeSession 接收
→ NodeInvokeDispatcher 路由到 CardReminderService.handleUpdateReminderCommand()
→ 解析 style=infoShowTitleImageAndImport → 校验 imageUrl 必填
→ 下载图片 → 推送到桌面卡片
→ 卡片以全幅背景图 + 右侧"拍一拍""选一选"按钮渲染
→ 返回 InvokeResult.ok({"ok":true,"formIdsCount":1})
```

**带 skill 参数的调用示例**：

```
智能体 → Gateway → node.invoke.request
{
  "command": "card.reminder.update",
  "paramsJson": "{\"style\":\"infoShowTitleImageAndImport\",\"body\":\"拍一张体检报告\",\"skill\":\"数据录入\"}"
}
→ HarmonyOS NodeSession 接收
→ NodeInvokeDispatcher 路由到 CardReminderService.handleUpdateReminderCommand()
→ 解析 skill=数据录入 → 存入 AppStorage('cardSkill')
→ 推送到桌面卡片（卡片内容不含 skill）
→ 用户点击"拍一拍"拍照后 → PhotoCaptureService 读 cardSkill='数据录入'
→ sendChat('/skill 数据录入', [attachment]) ← 代替默认的 '/ImageData'
```

---

## 十、后续对接与扩展方向

### 10.1 卡片点击路由（已实现）

卡片点击通过 `postCardAction` 发送 `router` 事件到 `EntryAbility.onNewWant()`，解析 `targetPage` 和 `importAction` 参数：

- `targetPage: 'import'` → 切换到 ImportPage
- `importAction: 'camera'` → ImportPage 自动触发拍照导入
- `importAction: 'gallery'` → ImportPage 自动触发相册导入

详见 6.8 节 EntryAbility 相关修改。

### 10.2 更多卡片风格

当前支持两种 style，未来可扩展更多风格，只需在 `ReminderCardWidget.ets` 的 `build()` 中新增风格分支，并在 `$style` 参数中定义新值即可。Agent 通过 Gateway 实时选择风格，无需用户手动切换卡片类型。

### 10.3 更多卡片尺寸

当前支持 2×2 和 2×4。后续如需 4×4 大卡片，只需：
1. `form_config.json` 中 `supportDimensions` 添加 `"4*4"`
2. `ReminderCardWidget.ets` 中根据尺寸调整布局比例（通过 `LOCAL_DIMENSION` 状态变量）

### 10.4 更多 Card Command

当前只有 `card.reminder.update`。后续可扩展：
- `card.reminder.clear` — 清除提醒，恢复默认内容
- `card.reminder.history` — 查询最近推送记录
- `card.image.update` — 单独更新图片

每个新 command 只需：
1. `OpenClawProtocolConstants.ets` 中新增 enum 条目
2. `InvokeCommandRegistry.ets` 中新增 spec
3. `NodeInvokeDispatcher.ets` 中新增 switch case
4. `CardReminderService.ets` 中新增 handler 方法

---

## 十一、实际文件树（新增后）

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets              # ★ +5行 onFormEvent
├── pages/
│   ├── Index.ets                     # 不改动
│   ├── OnboardingPage.ets            # 不改动
│   ├── PostOnboardingTabs.ets        # ★ 3处增量修改（+6行）
│   ├── ConnectPage.ets               # 不改动
│   ├── ChatPage.ets                  # 不改动
│   ├── VoicePage.ets                 # 不改动
│   ├── ScreenPage.ets                # 不改动
│   ├── SettingsPage.ets              # 不改动
│   ├── ImportPage.ets                # 不改动
│   ├── DebugPage.ets                 # ★ 新增
├── form/
│   ├── ReminderFormExtension.ets     # ★ 新增
│   └── pages/
│       └── ReminderCardWidget.ets    # ★ 新增
├── viewmodel/
│   └── MainViewModel.ets             # 不改动（invoke 路由在 NodeInvokeDispatcher 内部闭环）
├── model/
│   └── GatewayModels.ets             # 不改动
├── api/
│   └── ...                           # 不改动
├── service/
│   ├── PhotoCaptureService.ets       # 不改动
│   └ CardReminderService.ets         # ★ 新增
├── common/
│   └ SecurePrefs.ets                 # 不改动
├── node/
│   ├── InvokeCommandRegistry.ets     # ★ +5行（card command spec + capability）
│   └ NodeInvokeDispatcher.ets        # ★ +7行（card command 路由 + import）
├── protocol/
│   └ OpenClawProtocolConstants.ets   # ★ +6行（Card enum + CardCommand enum）

entry/src/main/resources/
├── base/
│   ├── element/string.json           # ★ +23条
│   ├── profile/
│   │   ├── main_pages.json           # 不改动
│   │   └ form_config.json            # ★ 新增
│   └── media/
│       └── icon.png                   # 不改动（卡片 alt 复用此图标）
├── zh_CN/element/string.json         # ★ +23条
├── en_US/element/string.json          # ★ +23条

entry/src/main/module.json5            # ★ +15行（FormExtension ability + 配置引用）
```

---

## 十二、实施顺序

1. 创建 `resources/base/profile/form_config.json`
2. 创建 `entry/src/main/ets/service/CardReminderService.ets`
3. 创建 `entry/src/main/ets/form/ReminderFormExtension.ets`
4. 创建 `entry/src/main/ets/form/pages/ReminderCardWidget.ets`
5. 创建 `entry/src/main/ets/pages/DebugPage.ets`
6. 修改 `entry/src/main/ets/protocol/OpenClawProtocolConstants.ets`（+Card enum + CardCommand enum）
7. 修改 `entry/src/main/ets/node/InvokeCommandRegistry.ets`（+card spec + capability）
8. 修改 `entry/src/main/ets/node/NodeInvokeDispatcher.ets`（+card 路由 + import）
9. 修改 `entry/src/main/ets/pages/PostOnboardingTabs.ets`（3处增量）
10. 修改 `entry/src/main/ets/entryability/EntryAbility.ets`（+onFormEvent）
11. 修改 `entry/src/main/module.json5`（+FormExtension + 配置引用）
12. 修改 3 × `string.json`（+23条/文件）
13. 编译验证 — DevEco Studio 构建
14. 真机/模拟器测试 — 添加桌面卡片 → 调试 Tab 推送内容 → 验证卡片更新
15. Gateway invoke 测试 — 通过 Gateway 发送 `card.reminder.update` 命令 → 验证卡片远程更新

---

## 十三、风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Form Kit 在模拟器上不支持 | 无法在模拟器验证卡片显示 | 在真机上测试；调试 Tab 的预览区可在模拟器验证布局逻辑 |
| `formProvider.updateForm()` 跨进程通信延迟 | 卡片内容更新有短暂延迟（通常 < 500ms） | 可接受，提醒类卡片不需要即时渲染 |
| 卡片进程无法访问网络图片 | `Image(imageUrl)` 可能无法加载 http URL | HarmonyOS 6 卡片支持网络图片；如果受限，改为使用 PixelMap 本地传递（后续扩展） |
| `formBindingData` 数据大小限制 | 系统限制约 10KB JSON | 当前数据量远小于限制（title+body+note+imageUrl < 1KB） |
| 用户未添加卡片时推送无目标 | `pushToAllForms()` 跳过推送 | 正常行为；formId 列表为空时打日志，不影响主应用运行 |