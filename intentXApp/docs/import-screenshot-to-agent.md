# Import Screenshot to Agent — 架构设计文档

## 1. 需求概述

用户在鸿蒙 NEXT 系统上截图后，点击左下角分享按钮，在分享面板中看到 IntentX 应用图标。点击后将截图直接上传给 OpenClaw Agent 处理。

### 核心目标

- 通过 HarmonyOS Share Kit 的 `ShareExtensionAbility` 注册为系统分享目标
- 复用现有 `PhotoCaptureService.obtainPhotoToProcess()` 的完整处理链路（读文件 → 压缩 → base64 → 发送）
- 最小侵入式修改，不改变现有 ImportPage / ChatPage 的任何逻辑

---

## 2. HarmonyOS NEXT 分享扩展机制

### 2.1 两种接收方式对比

| 接入方式 | 特点 | 适用场景 |
|---------|------|---------|
| **UIAbility + ohos.want.action.sendData** | 启动完整应用页面 | 需要用户额外操作（编辑、标注等） |
| **ShareExtensionAbility** | 嵌入式弹窗界面，UI 由应用自定义 | 快速操作，显示处理后状态 |

### 2.2 选择 ShareExtensionAbility

**理由**：
- 截图分享是"一触即发"的操作，用户期望快速完成
- ShareExtensionAbility 以卡片/面板形式展示，不打断用户当前上下文
- 内部仍可加载自定义页面（如显示"发送中…"状态）
- 不需要对现有 EntryAbility 做任何修改

### 2.3 关键技术组件

| 组件 | 来源 | 用途 |
|------|------|------|
| `ShareExtensionAbility` | `@kit.AbilityKit` | 接收系统分享调起的入口 |
| `UIExtensionContentSession` | `@kit.AbilityKit` | 管理分享面板的 UI 生命周期 |
| `systemShare.getSharedData(want)` | `@kit.ShareKit` | 解析 Want 中的分享数据 |
| `systemShare.SharedRecord` | `@kit.ShareKit` | 单条分享记录，包含 uri / utd / title |

---

## 3. 数据流全景图

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 用户在系统截图预览 → 点击分享 → 选择 IntentX                               │
│                                                                          │
│  系统截图 URI: file://media/Photo/xxx/IMG_xxx.png                        │
│                                                                          │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ ShareExtensionAbility (新增)                                              │
│                                                                          │
│ ① 前置检查: mainViewModel.isConnected ?                            │
│    ├─ NO  → AppStorage 写入 fail + "Gateway未连接，请先连接"          │
│    │        → session.loadContent('pages/ShareReceivePage')            │
│    │                                                                  │
│    └─ YES → 继续                                                       │
│                                                                        │
│ ② systemShare.getSharedData(want)                                     │
│    → SharedRecord { uri, utd, title }                                 │
│                                                                        │
│ ③ AppStorage: status='sending', session.loadContent('ShareReceivePage')│
│                                                                        │
│ ④ photoCaptureService.processSharedUri(record.uri)                    │
│    → obtainPhotoToProcess(photoResult)  ← 复用现有管线                 │
│      ├─ 成功 → AppStorage: status='success'                            │
│      ├─ 文件为空     → status='fail', error='图片文件为空'              │
│      ├─ 文件>20MB    → status='fail', error='图片过大，上限20MB'        │
│      ├─ 压缩后>5MB   → status='fail', error='压缩失败，无法发送'        │
│      └─ IO/编码异常  → status='fail', error=具体错误信息                │
│                                                                        │
│ ⑤ ShareReceivePage 读取 AppStorage 展示对应状态                        │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 与现有 ImportPage 流程的对比

```
ImportPage 流程:
  用户点 Import Tab → 拍照/选图 → obtainPhotoToProcess(result) → sendChat

Share 流程 (新增):
  系统截图 → 系统分享面板 → 选 IntentX → processSharedUri(uri)
                                              │
                                              └→ 后续完全复用 obtainPhotoToProcess
                                                 与 ImportPage 共享同一管线
```

---

## 4. 设计决策

### 决策 A: 使用 ShareExtensionAbility 而非 UIAbility

- **推荐**: ShareExtensionAbility
- **理由**: 嵌入面板形式，不打断用户当前上下文；官方的文件分享落地指南推荐此方式
- **风险**: ShareExtensionAbility 的 UI 大小受系统限制（通常占屏幕 60-70%），但对"发送中"状态展示足够

### 决策 B: 复用现有 PhotoCaptureService 管线

- **新增方法**: `processSharedUri(uri: string)` — 薄封装，从 URI 构造 PhotoResult 后调用 `obtainPhotoToProcess`
- **理由**: 避免重复实现文件读取/压缩/编码/发送逻辑；未来压缩/编码逻辑变更自动继承
- **侵入性**: 仅在 PhotoCaptureService 增加一个约 5 行的公共方法

### 决策 C: 发送到 ImportImage 会话

- 与 ImportPage 的行为保持一致：使用专用 `ImportImage` 会话避免主对话被心跳刷屏
- 用户可在聊天应用的 ChatPage 中切换到 ImportImage 会话查看 Agent 回复

### 决策 D: 三层异常处理机制

分享流程的异常分为三类，每类有独立的处理策略：

```
┌──────────────────────────────────────────────────────────────┐
│ 层级          检测点                处理方式                   │
├──────────────────────────────────────────────────────────────┤
│ ① 连接检查    ShareReceiveAbility  前置同步检查 isConnected   │
│               入口                  失败→立即弹窗，不进入管线  │
│                                    延迟 1.5s 自动关闭面板     │
├──────────────────────────────────────────────────────────────┤
│ ② 文件处理    obtainPhotoToProcess  每个错误分支写 AppStorage  │
│               内部各 return 点       包含 status + error 消息  │
│                                    ShareReceivePage 显示详情  │
├──────────────────────────────────────────────────────────────┤
│ ③ 发送结果    sendChat              WebSocket 异步回调         │
│               .then() / .catch()     成功→AppStorage success  │
│                                    失败→AppStorage fail      │
│                                    sendChat 是 void，          │
│                                    通过 AppStorage 回传结果   │
└──────────────────────────────────────────────────────────────┘
```

**为什么不在 PhotoCaptureService 内检查连接？**
- `sendChat` 内部会检查 `isConnected`，但此时文件已读入、压缩完成，浪费了 CPU 和内存
- 前置检查可"快速失败"，避免无效处理

**为什么 sendChat 不改成返回 Promise？**
- 改动面大，影响 ChatPage 的调用方式
- 用 AppStorage 回传结果，ShareReceivePage 的 `@StorageProp` 自动响应

### 决策 E: 页面通信使用 AppStorage

AppStorage keys 定义：

| Key | 类型 | 写入者 | 写入时机 | 读取者 |
|-----|------|-------|---------|-------|
| `shareReceiveStatus` | `'sending' \| 'success' \| 'fail'` | ShareReceiveAbility（初始）、PhotoCaptureService（结果） | 各错误分支 / sendChat 回调 | ShareReceivePage |
| `shareReceiveError` | `string` | ShareReceiveAbility、PhotoCaptureService | 失败时写入具体原因 | ShareReceivePage |
| `shareReceiveUri` | `string` | ShareReceiveAbility | 接收分享时写入 | ShareReceivePage（缩略图） |

ImportPage 不读取这些 key，不会产生干扰；ShareReceivePage 不在常规页面栈中，销毁后 AppStorage 残留不影响下次分享。

### 决策 F: 使用 pages/ShareReceivePage 而非内联 UI

- ShareExtensionAbility 通过 `session.loadContent('pages/ShareReceivePage')` 加载页面
- 页面需要注册到 `main_pages.json`
- 页面通过 `@StorageProp` 响应状态变化，成功后延迟 1.5s 自动关闭

---

## 5. 需要新增/修改的文件

### 5.1 新增文件

| 文件 | 用途 |
|------|------|
| `entry/src/main/ets/share/ShareReceiveExtensionAbility.ets` | ShareExtensionAbility 入口，接收分享 URI 并触发发送 |
| `entry/src/main/ets/pages/ShareReceivePage.ets` | 分享面板中显示的最小 UI（发送状态） |

### 5.2 修改文件

| 文件 | 修改内容 |
|------|---------|
| `entry/src/main/module.json5` | 在 `extensionAbilities` 中注册 ShareReceiveExtensionAbility |
| `entry/src/main/resources/base/profile/main_pages.json` | 添加 `pages/ShareReceivePage` |
| `entry/src/main/ets/service/PhotoCaptureService.ets` | 新增 `processSharedUri()` 方法；在每个错误路径写入 AppStorage 错误信息 |

---

## 6. 详细实现

### 6.1 module.json5 — 注册分享扩展

在 `extensionAbilities` 数组中添加:

```json
{
  "name": "ShareReceiveExtensionAbility",
  "srcEntry": "./ets/share/ShareReceiveExtensionAbility.ets",
  "type": "share",
  "exported": true,
  "icon": "$media:icon",
  "label": "$string:share_extension_label",
  "skills": [
    {
      "actions": ["ohos.want.action.sendData"],
      "uris": [
        {
          "scheme": "file",
          "utd": "general.image",
          "maxFileSupported": 1
        }
      ]
    }
  ]
}
```

**要点**:
- `type: "share"` — 声明为分享扩展
- `utd: "general.image"` — 通配所有图片格式（PNG/JPEG/HEIC 等），截图通常为 PNG
- `maxFileSupported: 1` — 每次处理 1 张图片
- `icon` 复用应用主图标

### 6.2 ShareReceiveExtensionAbility.ets

```typescript
import { ShareExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { mainViewModel } from '../viewmodel/MainViewModel';
import { photoCaptureService } from '../service/PhotoCaptureService';

export default class ShareReceiveExtensionAbility extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    // ── ① 前置检查：Gateway 连接状态 ──
    if (!mainViewModel.isConnected) {
      console.warn('ShareReceiveExtension: gateway not connected');
      AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
      AppStorage.setOrCreate<string>(
        'shareReceiveError',
        mainViewModel.chatError ||
          'Gateway is not connected. Please connect in the app first and try again.'
      );
      session.loadContent('pages/ShareReceivePage');
      return;
    }

    systemShare.getSharedData(want)
      .then((data: systemShare.SharedData) => {
        const records = data.getRecords();
        if (records.length === 0) {
          session.terminateSelf();
          return;
        }

        const record = records[0];
        console.info(
          'ShareReceiveExtension: received share, utd=' + record.utd +
          ', uri=' + record.uri
        );

        // ② 设置初始状态 + 加载 UI
        AppStorage.setOrCreate<string>('shareReceiveUri', record.uri);
        AppStorage.setOrCreate<string>('shareReceiveStatus', 'sending');
        AppStorage.setOrCreate<string>('shareReceiveError', '');
        session.loadContent('pages/ShareReceivePage');

        // ③ 复用现有图片处理管线（读文件 → 压缩 → base64 → 发送）
        photoCaptureService.processSharedUri(record.uri);
      })
      .catch((error: BusinessError) => {
        console.error(
          'ShareReceiveExtension: getSharedData failed, code=' +
          error.code + ', msg=' + error.message
        );
        AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
        AppStorage.setOrCreate<string>(
          'shareReceiveError',
          'Unable to read shared image. Please try again.'
        );
        session.loadContent('pages/ShareReceivePage');
      });
  }
}
```
```

### 6.3 PhotoCaptureService — 新增 processSharedUri + 错误路径写入

在 `PhotoCaptureService` 类中新增一个方法：

```typescript
/**
 * 从外部 URI 处理图片（系统分享等入口）。
 * 构造 PhotoResult 后委托给 obtainPhotoToProcess 完成后续管线。
 *
 * @param uri 图片文件 URI
 */
processSharedUri(uri: string): void {
  const photoResult = new PhotoResult();
  photoResult.uri = uri;
  photoResult.displayName = this.extractDisplayName(uri);
  this.obtainPhotoToProcess(photoResult);
}
```

**为什么需要此方法**：`obtainPhotoToProcess` 接收 `PhotoResult`，而系统分享直接提供 URI 字符串。此方法消除类型差异。

#### 6.3.1 obtainPhotoToProcess — 在每个错误分支写入 AppStorage

修改 `obtainPhotoToProcess` 方法，在每个 `return` 前写入失败原因：

```typescript
async obtainPhotoToProcess(photoResult: PhotoResult): Promise<void> {
  console.info('PhotoCaptureService: obtainPhotoToProcess called, uri=' + ...);

  try {
    let file = fileIo.openSync(photoResult.uri, fileIo.OpenMode.READ_ONLY);
    try {
      let stat = fileIo.statSync(file.fd);

      // P0-02: 文件为空
      if (stat.size <= 0) {
        console.error('PhotoCaptureService: file is empty, uri=' + photoResult.uri);
        AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
        AppStorage.setOrCreate<string>('shareReceiveError', 'Image file is empty.');
        return;
      }

      // P1-01: 安全上限检查
      if (stat.size > MAX_FILE_SIZE_BYTES) {
        console.error('PhotoCaptureService: file too large (' + stat.size + ' bytes)');
        AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
        AppStorage.setOrCreate<string>(
          'shareReceiveError',
          'Image is too large (' + Math.round(stat.size / 1048576) +
          ' MB). Maximum is 20 MB.'
        );
        return;
      }

      let buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);

      // 迭代压缩
      let finalBuffer = await this.compressToTarget(buffer, MAX_INLINE_BYTES);

      // 压缩后仍超 5MB 服务端上限
      if (finalBuffer.byteLength > SERVER_MAX_SIZE_BYTES) {
        console.error('PhotoCaptureService: compressed still too large');
        AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
        AppStorage.setOrCreate<string>(
          'shareReceiveError',
          'Image could not be compressed enough. Please try a smaller image.'
        );
        return;
      }

      let base64 = await this.base64Helper.encodeToString(new Uint8Array(finalBuffer));
      let mimeType = finalBuffer !== buffer ? 'image/jpeg'
        : this.inferMimeType(photoResult.displayName || photoResult.uri);
      let fileName = photoResult.displayName ||
        ('photo.' + this.extensionFromMimeType(mimeType));

      let attachment = new OutgoingAttachment();
      attachment.type = 'image';
      attachment.mimeType = mimeType;
      attachment.fileName = fileName;
      attachment.content = base64;

      // ── 发送成功，通过 AppStorage 通知 ShareReceivePage ──
      // 注意：sendChat 是 void，实际的 WebSocket 发送是异步的。
      // 此处为"已提交发送"的乐观成功；若 WebSocket 发送失败，
      // sendChat 内部的 .catch 会设置 chatError，用户可在 ChatPage 看到。
      mainViewModel.sendChat('/ImageData', 'off', [attachment]);
      AppStorage.setOrCreate<string>('shareReceiveStatus', 'success');
      console.info('PhotoCaptureService: photo sent, finalSize=' +
        finalBuffer.byteLength + ' bytes');

    } finally {
      fileIo.closeSync(file);
    }
  } catch (error) {
    let bizErr: BusinessError = error as BusinessError;
    console.error('PhotoCaptureService: obtainPhotoToProcess error, code=' +
      bizErr.code + ', msg=' + bizErr.message);
    AppStorage.setOrCreate<string>('shareReceiveStatus', 'fail');
    AppStorage.setOrCreate<string>(
      'shareReceiveError',
      'Failed to process image: ' + (bizErr.message || 'Unknown error.')
    );
  }
}
```

**关键变更总结**：

| 错误场景 | 检测点 | AppStorage 写入 |
|---------|--------|----------------|
| 文件为空 | `stat.size <= 0` | `status='fail'`, `error='Image file is empty.'` |
| 文件超 20MB | `stat.size > MAX_FILE_SIZE_BYTES` | `status='fail'`, `error='Image is too large (X MB)...'` |
| 压缩后超 5MB | `finalBuffer > SERVER_MAX_SIZE_BYTES` | `status='fail'`, `error='Image could not be compressed...'` |
| IO / 编码异常 | `catch` 块 | `status='fail'`, `error='Failed to process image: ...'` |
| 成功 | 正常流程末尾 | `status='success'` |

> **关于 sendChat 的异步问题**：`sendChat` 是 `void` 方法，WebSocket 发送在 `.then()/.catch()` 回调中异步完成。此处采用"乐观成功"策略——文件处理成功后即标记 success。若 WebSocket 发送失败，`sendChat` 内部会设置 `chatError`，用户可在 ChatPage 查看。这是与 ImportPage 当前行为一致的折中方案。未来可在 Phase 2 中将 `sendChat` 改造为返回 Promise，实现精确的成功/失败反馈。

### 6.4 ShareReceivePage.ets

```typescript
@Entry
@Component
struct ShareReceivePage {
  @StorageProp('shareReceiveStatus') status: string = 'sending';
  @StorageProp('shareReceiveUri') shareUri: string = '';
  @StorageProp('shareReceiveError') errorMsg: string = '';
  @StorageProp('localeVersion') localeVersion: number = 0;

  aboutToAppear(): void {
    // 重置状态，确保每次分享从干净状态开始
    AppStorage.setOrCreate<string>('shareReceiveStatus', 'sending');
    AppStorage.setOrCreate<string>('shareReceiveError', '');
  }

  build() {
    Column() {
      Column({ space: 16 }) {
        // ── 缩略图 ──
        if (this.shareUri.length > 0) {
          Image(this.shareUri)
            .width(120)
            .height(120)
            .objectFit(ImageFit.Cover)
            .borderRadius(12);
        }

        // ── 状态展示 ──
        if (this.status === 'sending') {
          LoadingProgress()
            .width(36)
            .height(36)
            .color('#1D5DD8');

          Text('Sending to Agent...')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#17181C');
        } else if (this.status === 'success') {
          Text('✓')
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2F8C5A');

          Text('Sent successfully!')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2F8C5A');
        } else {
          // 失败状态 — 展示具体错误原因
          Text('✗')
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#DC2626');

          Text('Send failed')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#DC2626');

          if (this.errorMsg.length > 0) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#4D5563')
              .textAlign(TextAlign.Center)
              .maxLines(4)
              .padding({ left: 16, right: 16 })
              .margin({ top: 4 });
          }
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width('100%')
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7FA')
    .onClick(() => {
      // 点击任意位置关闭面板
      if (this.status === 'success' || this.status === 'fail') {
        const session = AppStorage.get<UIExtensionContentSession>('shareSession');
        if (session) {
          session.terminateSelf();
        }
      }
    });
  }
}
```

**交互细节**：
- 加载后立即显示"发送中" + 缩略图 + 旋转动画
- 成功/失败后点击面板任意位置可关闭
- 失败时展示 `shareReceiveError` 中的具体原因

### 6.5 ShareReceiveExtensionAbility — 传递 session 引用

ShareReceivePage 关闭面板需要 `UIExtensionContentSession` 引用。在 `onSessionCreate` 中将 session 存入 AppStorage：

```typescript
// 在 onSessionCreate 开头
AppStorage.setOrCreate<UIExtensionContentSession>('shareSession', session);
```

或使用 ShareReceivePage 的内置机制：通过 `@Entry` 组件的 `router.getParams()` 获取 session。推荐 AppStorage 方式以保持简单。`main_pages.json` 中添加 `pages/ShareReceivePage`。

### 6.6 main_pages.json — 注册页面
```

---

## 7. 修改影响评估

| 修改项 | 类型 | 影响范围 |
|--------|------|---------|
| `module.json5` | 新增配置 | 仅注册 ShareExtensionAbility，不影响现有能力 |
| `ShareReceiveExtensionAbility.ets` | 新文件 | 独立模块，零耦合 |
| `ShareReceivePage.ets` | 新文件 | 独立页面，零耦合 |
| `PhotoCaptureService.processSharedUri()` | 新增方法 | 约 5 行，不改现有逻辑 |
| `PhotoCaptureService.obtainPhotoToProcess()` | 每个错误分支 +1 行 AppStorage 写入 | 共 +7 行，不影响 ImportPage 调用路径 |
| `main_pages.json` | 新增一行 | 标准页面注册 |

**总新增代码量**: ~130 行（3 个新文件 + 约 15 行修改）

---

## 8. 风险与边界条件

### 8.1 URI 权限

- 系统分享传入的 URI 已有临时读权限，无需额外申请
- 文件读取失败时 `obtainPhotoToProcess` 的 catch 会兜底

### 8.2 离线场景

- 如果设备未连接 Gateway，`sendChat` 内部会设置 `chatError`，不抛异常
- `obtainPhotoToProcess` 的 catch 块会将状态设为 `'fail'`
- ShareReceivePage 会显示"发送失败"

### 8.3 多文件分享

- 当前仅处理首张图片（`records[0]`），`maxFileSupported: 1` 限制单次 1 张
- 未来可扩展为遍历所有 record

### 8.4 分享面板图标

- 使用应用主图标 `$media:icon`，确保图标在系统分享面板中醒目可识别
- icon 必须是分层图标（layered image），已在 `AppScope/resources/media/` 中配置

### 8.5 ShareExtensionAbility 的限制

- ShareExtensionAbility 不支持窗口操作（如 `window.createWindow`）
- 只能通过 `session.loadContent('pages/xxx')` 加载页面
- session 引用需通过 AppStorage 传递给 ShareReceivePage 用于关闭

### 8.6 异常场景覆盖

| 异常场景 | 检测层 | 用户看到 |
|---------|-------|---------|
| Gateway 未连接 | ① 前置检查 (ShareReceiveAbility) | 红色 ✗ "Send failed" + "Gateway is not connected..." |
| 分享数据为空 | ② getRecords() 返回空 | `terminateSelf()` 直接关闭 |
| 图片文件为空 | ② obtainPhotoToProcess | 红色 ✗ "Image file is empty." |
| 图片 > 20MB | ② obtainPhotoToProcess | 红色 ✗ "Image is too large (X MB). Maximum is 20 MB." |
| 压缩后 > 5MB | ② obtainPhotoToProcess | 红色 ✗ "Image could not be compressed enough..." |
| 文件读取/编码失败 | ② catch 块 | 红色 ✗ "Failed to process image: ..." |
| WebSocket 发送失败 | ③ sendChat 异步回调 | 乐观成功（显示 ✓），错误在 ChatPage 的 chatError 中 |
| getSharedData 异常 | ② .catch() | 红色 ✗ "Unable to read shared image..." |

---

## 9. 未来演进路线

### Phase 1 — 当前

- [x] ShareExtensionAbility 接收系统分享图片
- [x] 复用 PhotoCaptureService 管线发送到 Agent
- [x] 基础 UI 状态展示（发送中 / 成功 / 失败 / 错误详情）
- [x] Gateway 连接前置检测 + 快速失败
- [x] 文件处理全链路异常覆盖（空文件/过大/压缩失败/IO异常）
- [ ] 端到端验证：截图 → 分享 → Agent 收到图片

### Phase 2 — 体验优化

- [ ] 发送成功后自动关闭面板（`setTimeout` 1.5s → `session.terminateSelf()`）
- [ ] 超时检测（> 30s 自动显示失败）
- [ ] 进度指示（压缩进度 / 发送进度）
- [ ] 支持多图分享

### Phase 3 — 能力扩展

- [ ] 点击分享面板图标直接发送（无需打开确认页面）
- [ ] 分享时允许附加文字说明
- [ ] Widget 快捷操作集成

---

## 10. 关键文件索引

| 文件路径 | 职责 |
|---------|------|
| `ets/share/ShareReceiveExtensionAbility.ets` | 分享入口，解析 URI → 调用发送管线 |
| `ets/pages/ShareReceivePage.ets` | 分享面板 UI（状态展示） |
| `ets/service/PhotoCaptureService.ets` | 新增 `processSharedUri()` + 状态写入 |
| `entry/src/main/module.json5` | 注册 ShareExtensionAbility |
| `entry/src/main/resources/base/profile/main_pages.json` | 注册 ShareReceivePage |
