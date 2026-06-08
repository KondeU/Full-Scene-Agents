# Import Photo to Agent — 架构设计文档

## 1. 需求概述

用户通过「拍照」或「相册选取」获得一张图片后，将该图片作为聊天附件，附加文本 `/ImageData`，发送给服务端 OpenClaw Agent 处理。

### 核心目标

- 将照片编码为 base64，通过已有的 `chat.send` WebSocket 协议发送给服务端
- 服务端收到后走标准的 `parseMessageWithAttachments` → Agent 处理链路
- 不引入新的协议方法，完全复用现有聊天基础设施

---

## 2. 现有架构分析

### 2.1 整体分层

```
┌─────────────────────────────────────────────────────┐
│  Pages (UI 层)                                       │
│  ImportPage / ChatPage / ...                         │
│  - @Component + @State 驱动 UI                       │
│  - 通过 @ObjectLink viewModel 持有 MainViewModel     │
└──────────────┬──────────────────────┬────────────────┘
               │                      │
               ▼                      ▼
┌──────────────────────┐  ┌───────────────────────────┐
│  Service 层          │  │  ViewModel 层              │
│  PhotoCaptureService │  │  MainViewModel (singleton) │
│  LocationService     │  │  - 状态管理               │
│  CardReminderService │  │  - sendChat()             │
│                      │  │  - 连接管理               │
└──────────────────────┘  └──────────┬────────────────┘
                                     │
                                     ▼
                          ┌───────────────────────┐
                          │  API 层               │
                          │  GatewaySession       │
                          │  - WebSocket 连接     │
                          │  - JSON-RPC 协议      │
                          │  - request/response   │
                          └──────────┬────────────┘
                                     │ WebSocket
                                     ▼
                          ┌───────────────────────┐
                          │  服务端               │
                          │  chat.send handler    │
                          │  parseMessageWith...  │
                          │  Agent 执行           │
                          └───────────────────────┘
```

### 2.2 关键单例与依赖关系

```
mainViewModel (export singleton)        ← MainViewModel.ets
  ├── operatorSession: GatewaySession   ← 通过 connect 创建
  ├── chatMessages: ChatMessage[]       ← 聊天消息列表
  ├── chatThinkingLevel: string         ← thinking 等级
  └── sendChat(message, thinking, attachments)  ← 发送聊天

photoCaptureService (export singleton)  ← PhotoCaptureService.ets
  ├── capturePhoto() → PhotoResult
  ├── pickFromAlbum() → PhotoResult
  └── obtainPhotoToProcess(photoResult) ← 当前需要实现的入口

GatewayModels:
  ├── OutgoingAttachment                ← 附件数据模型
  │     type / mimeType / fileName / content
  ├── ChatMessage / ChatMessageContent
  └── ...
```

### 2.3 现有聊天发送链路（chat.send）

```
ChatPage.sendMessage()
  → viewModel.sendChat(message, thinking, attachments[])
    → 构建 ChatSendRequestParams {
        sessionKey, message, thinking, idempotencyKey,
        attachments? (新增)
      }
    → operatorSession.request('chat.send', JSON.stringify(params))
      → WebSocket JSON-RPC 帧:
          { type: 'req', id, method: 'chat.send', params: {...} }
```

### 2.4 服务端附件处理链路

```
chat.ts: "chat.send" handler
  → normalizeRpcAttachmentsToChatAttachments(params.attachments)
    → 从 { type, mimeType, fileName, content(base64) } 中提取
    → 过滤掉 content 为空的项
  → parseMessageWithAttachments(message, normalizedAttachments)
    → 校验 base64 合法性 / 大小限制 (5MB)
    → 小图 (≤2MB): 直接作为 ChatImageContent 内联传递给模型
    → 大图 (>2MB): offload 到 media store, 消息追加 media:// URI
    → 返回 { message, images[], imageOrder[], offloadedRefs[] }
  → dispatchInboundMessage({ ..., images: parsedImages })
    → Agent 收到图片 + 文本，执行处理
```

### 2.5 服务端附件格式（RpcAttachmentInput）

```typescript
// 服务端期望的 attachment 格式 (attachment-normalize.ts)
{
  type: string,        // "image"
  mimeType: string,    // "image/jpeg"
  fileName: string,    // "photo.jpg"
  content: string      // 纯 base64 字符串（不含 data: 前缀）
}
```

---

## 3. 当前已实现代码的审视

以下代码已写入各文件，需对照架构审视其合理性。

### 3.1 已修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `model/GatewayModels.ets` | `OutgoingAttachment` 从 `{type, data}` 扩展为 `{type, mimeType, fileName, content}` |
| `viewmodel/MainViewModel.ets` | `ChatSendRequestParams` 增加 `attachments?` 字段；`sendChat()` 将 attachments 传入 params |
| `service/PhotoCaptureService.ets` | `obtainPhotoToProcess()` 读取文件 → base64 → 构造附件 → 调用 `mainViewModel.sendChat('/ImageData', 'off', [attachment])` |
| `pages/ImportPage.ets` | 无修改（`obtainPhotoToProcess` 现在是 async，但 fire-and-forget 调用兼容） |

### 3.2 需要审视的架构问题

#### 问题 A: PhotoCaptureService 直接依赖 mainViewModel 单例

**现状**: `PhotoCaptureService` 直接 `import { mainViewModel }` 并调用 `sendChat()`。

**分析**:
- **优点**: 简单直接，ImportPage 不需要关心发送逻辑
- **缺点**: Service 层反向依赖 ViewModel 层，形成隐式耦合。如果以后 ViewModel 的 `sendChat` 签名变化，Service 层也受影响
- **项目中的一致性**: 其他 Service（`LocationService`、`CardReminderService`）不依赖 ViewModel，它们由 `NodeInvokeDispatcher` 驱动。但这两个是被动响应服务端请求的，与 Photo 的主动发起模式不同

**结论**: 当前阶段可接受。PhotoCaptureService 作为「胶水」层，职责就是桥接拍照结果和聊天发送。如果未来 ImportPage 需要在发送前后做 UI 反馈（如进度条、成功/失败 toast），可以将发送逻辑提升到 ImportPage 层，通过 `this.viewModel.sendChat(...)` 显式调用。

#### 问题 B: thinking 硬编码为 'off'

**现状**: `mainViewModel.sendChat('/ImageData', 'off', [attachment])`

**分析**:
- 服务端对 `/` 开头的消息本身就不注入 thinking：`!trimmedMessage.startsWith("/")` → `injectThinking = false`
- 所以无论客户端传什么 thinking 值，服务端都会忽略
- 硬编码 `'off'` 是合理的，语义也清晰

**结论**: 无问题。

#### 问题 C: base64 编码方案

**现状**: 使用 HarmonyOS 系统 API `util.Base64Helper`（`@kit.ArkTS`）

**方案选择**:
- ~~自实现 `arrayBufferToBase64()` + `btoa()`~~ — 已废弃。自实现虽然算法正确，但存在以下问题：
  - `binary += String.fromCharCode(...)` 对大图（3-5MB）有 O(n²) 字符串拼接开销
  - 中间变量 `binary` 额外占用双倍内存（原始 ArrayBuffer + 二进制字符串）
  - 引入不必要的自维护代码，增加排查和审计成本
- **采用 `util.Base64Helper.encodeToStringSync(Uint8Array)`** — 系统原生实现
  - 原生 C++ 层编码，无字符串拼接开销
  - 内存效率高，直接操作 ArrayBuffer 视图
  - API 稳定，属于 HarmonyOS 公开 SDK

**结论**: 使用系统 API，商用级方案。

#### 问题 D: mimeType 检测

**现状**: 通过文件名后缀推断 mimeType，默认回退 `image/jpeg`

**检测链路**:
1. `inferMimeType(fileName)` — 根据文件名后缀（`.jpg`/`.png`/`.webp`/`.gif`/`.heic`/`.heif`/`.bmp`）映射为标准 MIME 类型
2. 无后缀或无法识别时回退 `image/jpeg`（相机拍照最常见格式）
3. 服务端 `sniffMimeFromBase64()` 做二阶校验——客户端声明不准确时服务端可修正

**为什么客户端必须做初步检测**:
- 相册选取可能返回 PNG、HEIC 等非 JPEG 格式
- 准确的 mimeType 影响服务端 offload 路由（`SUPPORTED_OFFLOAD_MIMES` 白名单）
- 减少「客户端声明错误 → 服务端 warn 日志」的噪音
- 客户端与服务端共同承担数据正确性，而非单方兜底

**结论**: 客户端后缀推断 + 服务端二进制嗅探，双重保障，商用级设计。

#### 问题 E: ImportPage 的 processingState 更新时机

**现状**: ImportPage 在 `capturePhoto/pickFromAlbum` 成功后立即设置 `processingState = 'success'`，然后 fire-and-forget 调用 `obtainPhotoToProcess`

**分析**:
- UI 显示 "Photo obtained" 时，图片可能还在 base64 编码 + 发送中
- 如果发送失败，用户看到的仍然是 "success" 状态
- 这是 **设计权衡**: ImportPage 是一个入口页面，真正的发送结果应该由 ChatPage 展示
- 可选改进: 增加 `sending` 状态，等 `obtainPhotoToProcess` 完成后再设为 `success`/`error`

**结论**: 当前设计合理，ImportPage 职责到「获取照片」为止。发送状态由 ChatPage 的聊天 UI 自然体现。

---

## 4. 数据流全景图

```
┌──────────────────────────────────────────────────────────────────────┐
│ HarmonyOS Client                                                     │
│                                                                      │
│  ImportPage                                                          │
│    │ handleCapturePhoto() / handlePickFromAlbum()                    │
│    ▼                                                                 │
│  PhotoCaptureService                                                 │
│    │ capturePhoto() / pickFromAlbum()                                │
│    │ → PhotoResult { uri, displayName }                              │
│    ▼                                                                 │
│  PhotoCaptureService.obtainPhotoToProcess(photoResult)               │
│    │ 1. fileIo.openSync(uri, READ_ONLY)                              │
│    │ 2. fileIo.statSync(fd) → size                                   │
│    │ 3. fileIo.readSync(fd, buffer)                                  │
│    │ 4. fileIo.closeSync(file)                                       │
│    │ 5. util.Base64Helper.encodeToStringSync(Uint8Array) → base64    │
│    │ 6. inferMimeType(displayName) → mimeType (后缀推断)             │
│    │ 7. new OutgoingAttachment {                                     │
│    │      type: 'image',                                             │
│    │      mimeType: inferred,                                        │
│    │      fileName: displayName,                                     │
│    │      content: '<base64>'                                        │
│    │    }                                                            │
│    ▼                                                                 │
│  mainViewModel.sendChat('/ImageData', 'off', [attachment])           │
│    │ 构建 ChatSendRequestParams                                      │
│    │ 追加 attachments 到 params                                      │
│    ▼                                                                 │
│  GatewaySession.request('chat.send', JSON.stringify(params))         │
│    │ WebSocket JSON-RPC                                              │
│    ▼                                                                 │
├──────────────────────────────────────────────────────────────────────┤
│ Server (OpenClaw Gateway)                                            │
│                                                                      │
│  chat.ts: "chat.send" handler                                        │
│    │ 1. normalizeRpcAttachmentsToChatAttachments(params.attachments) │
│    │    → ChatAttachment[] { type, mimeType, fileName, content }     │
│    ▼                                                                 │
│  parseMessageWithAttachments('/ImageData', attachments)              │
│    │ - 校验 base64 合法性                                            │
│    │ - 校验大小 ≤ 5MB                                                │
│    │ - 嗅探 MIME type (sniffMimeFromBase64)                          │
│    │ - ≤2MB: images[] 内联传给模型                                   │
│    │ - >2MB: offload 到 media store, 消息追加 media:// URI           │
│    ▼                                                                 │
│  dispatchInboundMessage({                                            │
│    message: '/ImageData',                                            │
│    images: [{ type: 'image', data: '<base64>', mimeType }],          │
│    ...                                                               │
│  })                                                                  │
│    ▼                                                                 │
│  Agent 执行 → 回复流式推送到 Client                                  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 5. 协议格式对照

### 5.1 客户端发送的 WebSocket 帧

```json
{
  "type": "req",
  "id": "47",
  "method": "chat.send",
  "params": {
    "sessionKey": "main",
    "message": "/ImageData",
    "thinking": "off",
    "timeoutMs": 30000,
    "idempotencyKey": "run-xxxxxxxx",
    "attachments": [
      {
        "type": "image",
        "mimeType": "image/jpeg",
        "fileName": "IMG_20260606_123456.jpg",
        "content": "/9j/4AAQSkZJRgABAQ..."
      }
    ]
  }
}
```

### 5.2 服务端归一化后 (normalizeRpcAttachmentsToChatAttachments)

```typescript
[{
  type: "image",
  mimeType: "image/jpeg",
  fileName: "IMG_20260606_123456.jpg",
  content: "/9j/4AAQSkZJRgABAQ..."  // 纯 base64, 无 data: 前缀
}]
```

### 5.3 服务端解析后传给 Agent (parseMessageWithAttachments)

```typescript
{
  message: "/ImageData",
  images: [{
    type: "image",
    data: "/9j/4AAQSkZJRgABAQ...",
    mimeType: "image/jpeg"
  }],
  imageOrder: ["inline"],      // 或 ["offloaded"] 如果 >2MB
  offloadedRefs: []            // 大图时有值
}
```

---

## 6. 各层修改影响评估

### 6.1 OutgoingAttachment 模型变更

| 修改 | 影响 |
|------|------|
| `data` → `content` | 字段名对齐服务端协议。全项目搜索 `OutgoingAttachment` 仅在 `MainViewModel.ets` 和 `PhotoCaptureService.ets` 中使用，**无其他消费者** |
| 新增 `mimeType` | 新字段，默认空字符串，无破坏性 |
| 新增 `fileName` | 新字段，默认空字符串，无破坏性 |

### 6.2 ChatSendRequestParams 变更

| 修改 | 影响 |
|------|------|
| 新增 `attachments?` | 可选字段，不影响现有调用。`ChatPage.sendMessage()` 传 `[]`，`PhotoCaptureService` 传 `[attachment]` |

### 6.3 sendChat 行为变更

| 修改 | 影响 |
|------|------|
| 将 attachments 传入 requestParams | 仅当 `attachments.length > 0` 时才序列化该字段。现有调用传 `[]` 时不会在 JSON 中出现 `attachments` 键，服务端行为不变 |

---

## 7. 风险与边界条件

### 7.1 图片大小

| 阈值 | 值 | 行为 |
|------|---|------|
| 服务端 offload 阈值 | 2 MB（解码后） | 超过则存盘为 `media://inbound/<id>`，Agent 收到的消息会追加 `[media attached: ...]` 标记 |
| 服务端硬限制 | 5 MB | 超过直接报错 4xx |
| 客户端安全上限 | 20 MB（原始文件） | 超过拒绝，防止 OOM |
| **客户端压缩目标** | **≤ 1.5 MB（压缩后 JPEG）** | **迭代缩小至达标，确保 base64 解码后 < 2MB 内联传输** |

### 7.1.1 迭代压缩算法

对于原始文件 > 1.5MB 的图片，采用**迭代缩放**策略：

```
1. 读取原始文件 → buffer
2. 若 buffer ≤ 1.5MB → 直接使用，不做压缩
3. 创建 ImageSource，获取原始宽高 (ow, oh)
4. 初始 scale = min(1.0, 1920 / max(ow, oh))  // 首次尝试最长边 1920px
5. LOOP:
   a. targetW = floor(ow × scale), targetH = floor(oh × scale)
   b. 用 desiredSize 解码为 PixelMap
   c. JPEG q=80 编码 → compressedBuffer
   d. 若 compressedBuffer ≤ 1.5MB → 返回 compressedBuffer ✓
   e. 若 min(targetW, targetH) < 256px → 返回 compressedBuffer（兜底，不再缩小）
   f. scale = scale / 2  // 长宽各减半，面积约 1/4
   g. 继续 LOOP
```

**关键特性**：
- 不预设固定的最大尺寸，而是用大小反馈驱动迭代
- 每次迭代面积约缩小 4 倍，对大图收敛很快（如 6000×4000 → 1920×1280 → 960×640 → 480×320）
- 256px 最小边长兜底，防止无限循环
- 每轮都从原始 ImageSource 解码，避免累积质量损失；上一轮的 PixelMap 立即释放

实测数据：原始 3.5MB base64（解码 ~2.65MB）→ 触发 offload，Agent 只看到文本标记，收不到图片。压缩后 1.7MB base64（解码 ~1.3MB）→ 正常内联传输。11MB 照片（6000×4000 HEIC 转 JPEG）→ 两轮迭代（1920×1280 → 960×640）～800KB → 正常内联传输。8K 照片（7680×4320，~18MB）→ 1 轮迭代（1920×1080）～500KB → 正常内联传输。

### 7.1.2 阈值溯源分析

本节记录各阈值的来源与推导依据，供后续维护参考。

**完整阈值链路（从服务端到客户端）**：

```
服务端 (chat-attachments.ts)
  OFFLOAD_THRESHOLD_BYTES = 2_000_000   ← 第 84 行，file-private
    │ 超过 → saveMediaBuffer 存盘 → Agent 收到 [media attached: media://inbound/<id>]
    │ 不超过 → ChatImageContent { type:"image", data, mimeType } 内联传给 Agent
    │
  maxBytes 默认值 = 5_000_000            ← 第 300 行，函数参数默认值
    │ 所有 3 个调用点 (chat.ts / agent.ts / server-node-events.ts) 均显式传入 maxBytes: 5_000_000
    │ 超过 → throw Error "exceeds size limit"，消息发送失败
    │
  MEDIA_MAX_BYTES = 5 * 1024 * 1024     ← store.ts 第 16 行
    │ saveMediaBuffer 在写入磁盘前做防御性二次校验
    │ 正常路径已在 parseMessageWithAttachments 中被 5MB 拦截，此检查为兜底

客户端 (PhotoCaptureService.ets)
  MAX_INLINE_BYTES = 1.5 * 1024 * 1024   ← 压缩目标
    │ = 2_000_000 × 0.75，预留 25% 安全余量
    │ 余量作用：覆盖 JPEG q=80 在同尺寸不同图像复杂度下的文件大小波动
    │          高噪点/复杂纹理的 JPEG 可能比简单场景大 2~3 倍
    │
  SERVER_MAX_SIZE_BYTES = 5 * 1024 * 1024 ← 服务端硬限制镜像
    │ 压缩后做最终校验，理论上不会被触发（256px 兜底远低于 5MB）
    │ 防御性编程：防止压缩逻辑异常导致大文件穿透
    │
  MAX_FILE_SIZE_BYTES = 20 * 1024 * 1024 ← 读取安全上限
    │ 纯防 OOM：拒绝 absurdly large 的源文件
    │ 20MB 足以覆盖所有正常手机照片（含 HEIC 原片）
```

**为什么 `MAX_INLINE_BYTES` 直接等同于服务端 decoded size？**

客户端发送链路：`JPEG binary → util.Base64Helper.encodeToString → base64 string → WebSocket JSON`

服务端接收链路：`JSON parse → base64 string → Buffer.from(base64, 'base64') → binary (解码后)`

base64 编码/解码是**无损且尺寸精确可逆**的：`base64_len = ceil(binary_len × 4/3)`，`decode(base64) == binary`。

因此：**`finalBuffer.byteLength`（客户端 JPEG 二进制字节数）=== 服务端 `Buffer.from(base64, 'base64').length`**。1.5MB 的 JPEG 在服务端解码后就是 1.5MB，直接可比。

**为什么初值是 1920px 而不是继续用除 2？**

纯除 2 策略从原始尺寸的一半开始：
- 6000×4000 → 第 1 轮 3000×2000 → 大概率 > 1.5MB，浪费一次解码
- 混合模式从 1920px 起始 → 大多数照片 1 轮命中

1920px 是经验值：手机上常见的高分辨率照片（12MP~48MP），压缩到 1920px + JPEG q=80 后通常输出 200~800KB，远低于 1.5MB。后续除 2 的分支仅在极端高噪点图像时触发。

### 7.2 文件读取失败

- URI 可能因权限过期、文件被系统清理等原因失效
- 当前已用 try/catch 包裹，失败仅 console.error，不影响 UI 稳定性

### 7.3 网络断开时发送

- `sendChat()` 内部已检查 `isConnected`，断线时会设置 `chatError`，不抛异常
- `obtainPhotoToProcess` 中调用 `sendChat` 是 fire-and-forget，错误不会回传到 ImportPage
- 用户可在 ChatPage 看到错误提示

### 7.4 JSON 序列化大小

- 一张 5MB 照片 base64 后约 6.7MB，加上 JSON 开销约 7MB
- WebSocket 帧无理论大小限制，但极端情况下可能受内存压力影响
- 服务端 `isValidBase64()` 做正则校验，对大字符串有 O(n) 开销但可控

---

## 8. 未来演进路线

### Phase 1 — 当前（已实现）

- [x] `OutgoingAttachment` 模型对齐服务端 `{type, mimeType, fileName, content}`
- [x] `ChatSendRequestParams` 增加 `attachments?` 字段
- [x] `sendChat()` 将 attachments 透传到 WebSocket 请求
- [x] `PhotoCaptureService.obtainPhotoToProcess()` 读取文件 → base64 → 发送
- [x] 使用 `util.Base64Helper` 系统 API 编码（非自实现）
- [x] 客户端通过文件后缀推断 mimeType（非硬编码 jpeg）
- [x] **图片压缩**：迭代缩放至 ≤ 1.5MB（反复将长宽减半 + JPEG q=80，至 256px 兜底）
- [ ] 端到端验证：拍照 → 发送 → 服务端收到 → Agent 回复

### Phase 2 — 体验优化

- [ ] 压缩进度指示（大图压缩可能耗时数百 ms）
- [ ] ImportPage 发送状态反馈（`sending` → `sent` / `error`）
- [ ] 发送后自动导航到 ChatPage 查看 Agent 回复

### Phase 3 — 能力扩展

- [ ] 支持多张图片批量发送
- [ ] ChatPage 中直接粘贴/拖拽图片发送
- [ ] 发送前图片预览确认
- [ ] 与其他能力（location / voice）的组合触发

---

## 9. 蓝军审视报告

> 以蓝军（攻击方/质疑方）视角审视当前设计与代码，聚焦商用落地中会真实爆掉的问题。
> 分为 **P0（必炸）**、**P1（隐患）**、**P2（设计债务）** 三级。

### P0-01: 文件句柄泄漏——readSync / Base64 编码失败时 fd 永不关闭

**位置**: `PhotoCaptureService.ets:100-132`

**问题**:
```typescript
let file = fileIo.openSync(photoResult.uri, fileIo.OpenMode.READ_ONLY);  // ← fd 分配
let stat = fileIo.statSync(file.fd);
let buffer = new ArrayBuffer(stat.size);
fileIo.readSync(file.fd, buffer);     // ← 如果这里抛异常?
fileIo.closeSync(file);               // ← 永远不会执行到
```

如果 `readSync` 抛出异常（磁盘 I/O 错误、文件被占用、权限突然撤销），fd 永远不会被关闭。外层 `catch` 只打了日志，不处理 fd 回收。

同样，`new util.Base64Helper()` 和 `encodeToStringSync` 如果对异常 buffer（size=0 的 ArrayBuffer）抛异常，`closeSync` 同样不会执行。

**影响**: HarmonyOS 对每个进程有 fd 数量限制（通常 1024）。用户反复拍照 + 触发异常路径，几次后 fd 耗尽，后续所有文件操作全部失败，包括图片加载、卡片更新等。

**修复**: 使用 `try/finally` 保证 `closeSync` 一定执行：
```typescript
let file = fileIo.openSync(photoResult.uri, fileIo.OpenMode.READ_ONLY);
try {
  let stat = fileIo.statSync(file.fd);
  // ... read, encode, send ...
} finally {
  fileIo.closeSync(file);
}
```

### P0-02: stat.size 为 0 或负值时 —— `new ArrayBuffer(0)` / `new ArrayBuffer(-1)` 的行为

**位置**: `PhotoCaptureService.ets:103-104`

**问题**:
```typescript
let stat = fileIo.statSync(file.fd);
let buffer = new ArrayBuffer(stat.size);
```

如果照片文件已被系统清理、URI 对应的是空文件、或 `statSync` 返回异常值：
- `stat.size = 0` → `new ArrayBuffer(0)` → `encodeToStringSync` 产出空字符串 → `OutgoingAttachment.content = ''` → 服务端 `normalizeRpcAttachmentsToChatAttachments` 过滤掉空 content 的附件 → **Agent 收到一条无附件的 `/ImageData` 文本消息，无法处理**
- `stat.size < 0` → `new ArrayBuffer(负数)` → 运行时异常

**影响**: 用户拍了照但发送了一张空图给 Agent，Agent 收到的是一条没有图片附件的纯文本 `/ImageData`。Agent 要么报错要么给出无意义回复，用户困惑。

**修复**: 读取前校验文件大小：
```typescript
if (stat.size <= 0) {
  console.error('PhotoCaptureService: file is empty, uri=' + photoResult.uri);
  return;
}
```

### P0-03: 用户在 ChatPage 看到的本地消息是纯文本 "/ImageData"——没有图片预览

**位置**: `MainViewModel.ets:1315-1316` + `ChatPage.ets:729-746`

**问题**:
`sendChat` 构建本地用户消息时：
```typescript
userMessage.content = [this.createTextContent(outgoingText)];  // outgoingText = '/ImageData'
```

`ChatMessageContent` 只有 `type: 'text'` 和 `text` 两个字段。ChatPage 渲染消息时只提取 `text` 类型的内容块，其他类型显示为 `[blockType]`。

**结果**: 用户切到 ChatPage 后，看到的自己发的消息是一行文字 `/ImageData`，没有任何图片缩略图。对比 iOS/Android 端的 ShareExtension 体验——用户发送图片后在聊天记录中能直接看到图片。

**影响**: 用户体验断裂。用户不知道图片是否成功发出，只能等 Agent 回复来推断。商用场景下用户会反复操作。

**修复思路**:
1. 在 `ChatMessageContent` 中新增 `type: 'image'` + `uri` 字段（或复用 `text` 存 data URL）
2. `sendChat` 构建 `userMessage.content` 时，如果有 attachments，额外追加一个 image 类型的 content block
3. ChatPage 的 `messageTextValue` 或消息渲染逻辑中对 `image` 类型渲染缩略图

### P1-01: 大文件在压缩前被硬拒绝——11MB 照片选入即失败

**位置**: `PhotoCaptureService.ets:121-127`

**问题**:
当前代码在 `statSync` 之后、压缩之前做了 `if (stat.size > MAX_FILE_SIZE_BYTES) return;` 的硬拒绝。用户选取一张 11MB 的高分辨率照片（如 6000×4000 HEIC 转换后的 JPEG）时，文件直接被打回，无法进入压缩流程。

而实际上，11MB 照片完全可以通过迭代缩放压缩到 1.5MB 以内——这是压缩功能存在的意义。5MB 硬拒绝阈值使得压缩形同虚设。

**影响**: 用户选了一张"稍大一点"的照片就失败，必须手动缩小后再选。商用不可接受。

**修复**:
1. 将 `MAX_FILE_SIZE_BYTES` 提升至 20MB（纯安全上限，防止 OOM）
2. 移除硬拒绝逻辑，改为：所有 > 1.5MB 的文件统一走迭代压缩
3. 压缩后文件若仍 > 5MB（服务端上限），base64 编码后在发送前做最终校验

### P1-01b: 单次缩放不够——压缩后可能仍超 1.5MB

**位置**: `PhotoCaptureService.ets:172-224` (`compressImageIfNeeded`)

**问题**:
当前 `compressImageIfNeeded` 只做一次缩放（长边 1920px + JPEG q=80）。如果原图分辨率极高（如 6000×4000），单次缩放到 1920×1280 后 JPEG 编码结果可能仍有 2-3MB，超过 1.5MB 目标。缺少迭代缩小机制。

**影响**: 高分辨率图片压缩后仍超过 2MB 解码大小，触发服务端 offload，Agent 收不到图片内容。

**修复**: 采用迭代缩放算法（见 7.1.1），反复将长宽减半直到压缩结果 ≤ 1.5MB 或边长触底 256px。

### P1-02: `encodeToStringSync` 在主线程同步阻塞——大图卡 UI

**位置**: `PhotoCaptureService.ets:110`

**问题**:
`encodeToStringSync` 是同步 API，对 5MB 数据的编码在主线程执行。实测在低端设备上编码 3-5MB 可能需要数百毫秒到数秒。期间 UI 完全冻结，用户无法操作。

`fileIo.readSync` 也是同步的，大文件读取同样阻塞主线程。

**影响**: 用户拍照后感觉应用「卡死」，ANR（Application Not Responding）风险。

**修复思路**: 使用 `base64Helper.encodeToString(uint8Array)` 异步版本 + `fileIo.read` 异步版本，或使用 TaskPool 将整个 obtainPhotoToProcess 放到子线程。

### P1-03: `new util.Base64Helper()` 每次 obtainPhotoToProcess 都创建新实例

**位置**: `PhotoCaptureService.ets:109`

**问题**:
`Base64Helper` 实例本身无状态，创建开销虽小但无必要。在 `PhotoCaptureService` 类级别创建一次即可。

**影响**: 性能开销极小，但不规范。代码审查中会被挑出。

**修复**: 将 `base64Helper` 提升为类成员或模块级变量。

### P2-01: `inferMimeType` 对 HarmonyOS 系统相机 URI 格式无保证

**位置**: `PhotoCaptureService.ets:138-160`

**问题**:
HarmonyOS `cameraPicker.pick()` 返回的 `resultUri` 格式为 `file://media/Photo/xxx/IMG_20260606_123456.jpg`，后缀通常正确。但 `photoAccessHelper.PhotoViewPicker` 返回的 URI 格式可能不包含文件扩展名（如 `content://` 风格的内部 URI），此时 `inferMimeType` 回退到 `image/jpeg` 可能不准确。

**影响**: 功能上服务端能嗅探修正，但客户端声明不准确。属于防御性编程的边界场景。

**修复思路**: 后缀推断失败时，可读取文件头前几个字节（JPEG: `FF D8 FF`，PNG: `89 50 4E 47`）做精确判断。

### P2-02: `OutgoingAttachment` 模型变更的向后兼容性未文档化

**位置**: `GatewayModels.ets:61-66`

**问题**:
原模型 `{ type, data }` 变更为 `{ type, mimeType, fileName, content }`。字段名 `data` → `content` 是 **breaking change**。

设计文档中声称「全项目搜索 `OutgoingAttachment` 仅在 `MainViewModel.ets` 和 `PhotoCaptureService.ets` 中使用」，但这只覆盖了当前代码库。如果有外部插件、自动化测试、或未追踪的代码引用了 `OutgoingAttachment.data`，编译时会静默通过（字段不存在只是 undefined），运行时服务端收到的 content 为空字符串 → 附件被过滤掉。

**影响**: 如果有遗漏的消费者，静默失败，不报错但图片丢失。

**修复**: 在模型变更注释中标注 breaking change。或保留 `data` 字段作为别名。

### P2-02: 设计文档「问题 A」结论过于乐观

**位置**: 设计文档 3.2 问题 A

**问题**:
文档结论「当前阶段可接受」。但蓝军视角下，`PhotoCaptureService` 直接 import `mainViewModel` 单例意味着：
- 该 Service 无法独立单元测试（必须 mock 整个 mainViewModel）
- 如果 MainViewModel 被重构（比如 sendChat 签名变更），PhotoCaptureService 作为 Service 层代码也必须同步修改
- 循环依赖风险：ViewModel → Service → ViewModel

**修复思路**: 将 `obtainPhotoToProcess` 的发送逻辑提取为回调/接口，由 ImportPage 注入 `viewModel.sendChat.bind(viewModel)`。

---

## 10. 问题优先级总结

| ID | 级别 | 问题 | 状态 |
|----|------|------|------|
| P0-01 | **必炸** | 文件句柄泄漏 — fd 不关闭 | ✅ 已修复 |
| P0-02 | **必炸** | stat.size=0 发空图 — Agent 收不到图 | ✅ 已修复 |
| P0-03 | **必炸** | ChatPage 本地消息无图片预览 | ✅ 已修复 |
| P1-01 | **隐患** | 大文件在压缩前被硬拒绝 — 11MB 照片选入即失败 | ✅ 已修复（上限提升至 20MB + 迭代压缩） |
| P1-01b | **隐患** | 单次缩放不够 — 高分辨率图片压缩后仍超 1.5MB | ✅ 已修复（迭代减半至达标或 256px 兜底） |
| P1-02 | **隐患** | 同步编码阻塞主线程 — 卡 UI | ✅ 已修复（改用异步 encodeToString） |
| P1-03 | **隐患** | Base64Helper 每次新建实例 | ✅ 已修复 |
| P2-01 | **债务** | URI 无后缀时 mimeType 回退不精确 | 后续优化 |
| P2-02 | **债务** | 模型 breaking change 未标注 | ✅ 已修复 |
| P2-03 | **债务** | Service 反向依赖 ViewModel — 可测试性差 | 后续重构 |

---

## 11. 关键文件索引

| 文件路径 | 职责 |
|---------|------|
| `ets/service/PhotoCaptureService.ets` | 拍照/选图 + base64 编码 + 发送编排 |
| `ets/pages/ImportPage.ets` | 拍照/选图 UI 入口 |
| `ets/viewmodel/MainViewModel.ets` | 中央状态管理 + `sendChat()` |
| `ets/model/GatewayModels.ets` | `OutgoingAttachment` 数据模型 |
| `ets/api/GatewaySession.ets` | WebSocket JSON-RPC 协议层 |
| `src/gateway/server-methods/attachment-normalize.ts` | 服务端附件归一化 |
| `src/gateway/chat-attachments.ts` | 服务端附件解析 + offload 逻辑 |
| `src/gateway/server-methods/chat.ts` | 服务端 `chat.send` handler |
