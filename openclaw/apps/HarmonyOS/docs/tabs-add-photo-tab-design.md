# "导入" Tab 页面 — 详细设计方案

> 基于现有架构的最小侵入式新增 Tab 设计，优先新增文件、最小化修改已有代码。

---

## 一、需求摘要

- 在 PostOnboardingTabs 中新增第 6 个 Tab，名称"导入"（Tab 索引 = 5）
- 页面内左右两个大按钮："拍照"和"相册"
- 拍照：调用 HarmonyOS 相机拍照 -> 存入相册 -> 取得该照片 URI
- 相册：调用 HarmonyOS PhotoViewPicker 选取一张照片 -> 取得照片 URI
- 取得照片后调用 `obtainPhotoToProcess(uri)` -- 当前仅 console.log，后续由其他同学对接

---

## 二、改动范围总览

| 类型 | 文件 | 改动性质 | 改动量 |
|------|------|----------|--------|
| **新增** | `pages/ImportPage.ets` | 新 Tab 页面完整 UI | ~150 行 |
| **新增** | `service/PhotoCaptureService.ets` | 相机拍照 + 相册选取 + obtainPhotoToProcess | ~80 行 |
| **修改** | `PostOnboardingTabs.ets` | 添加 import、条件渲染分支、TabItem | ~6 行增量 |
| **修改** | `module.json5` | 新增相机权限声明 | +1 条 requestPermissions |
| **修改** | `resources/base/element/string.json` | 新增国际化 key | ~15 条 |
| **修改** | `resources/zh_CN/element/string.json` | 新增中文翻译 | ~15 条 |
| **修改** | `resources/en_US/element/string.json` | 新增英文翻译 | ~15 条 |

**不改动**：`MainViewModel.ets`、`GatewayModels.ets`、`SecurePrefs.ets`、任何已有 Page 文件、`EntryAbility.ets`

**核心设计原则**：导入 Tab 的照片获取是纯本地操作，不依赖 Gateway 连接状态，因此**不需要往 MainViewModel 中添加任何字段或监听器**。所有照片逻辑封装在独立的 `PhotoCaptureService` 中，ImportPage 仅持有该服务的引用和本地 UI 状态。

---

## 三、新增文件详细设计

### 3.1 `service/PhotoCaptureService.ets` -- 照片获取服务

**定位**：纯逻辑层，封装 HarmonyOS 相机与相册 API，隔离平台细节。ImportPage 通过此服务获取照片 URI，不直接调用系统 API。

**目录路径**：`entry/src/main/ets/service/PhotoCaptureService.ets`

**为什么独立成文件而非写在 ImportPage 内部？**
1. `obtainPhotoToProcess` 是后续对接其他同学功能的入口点，独立文件便于他人定位和修改
2. 相机/相册 API 属于平台细节，与 UI 关注点分离，遵循现有项目 service 层约定
3. ImportPage 只需处理 UI 状态变化，不关心底层 API 调用细节

**完整代码设计**：

```typescript
import { camera } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.PhotoAccessKit';

export class PhotoResult {
  uri: string = '';
  displayName: string = '';
}

export class PhotoCaptureService {
  async pickFromAlbum(): Promise<PhotoResult | null> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;

      const result = await picker.select(options);
      if (!result || !result.photoUris || result.photoUris.length === 0) {
        console.info('PhotoCaptureService: album pick returned no URI');
        return null;
      }

      const uri = result.photoUris[0];
      const photoResult = new PhotoResult();
      photoResult.uri = uri;
      photoResult.displayName = this.extractDisplayName(uri);
      console.info('PhotoCaptureService: album pick success, uri=' + uri);
      return photoResult;
    } catch (error) {
      console.error('PhotoCaptureService: pickFromAlbum error:', error);
      return null;
    }
  }

  async capturePhoto(): Promise<PhotoResult | null> {
    try {
      const picker = new camera.CameraViewPicker();
      const options = new camera.CameraViewPickerOptions();
      options.MIMEType = camera.CameraViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;

      const result = await picker.select(options);
      if (!result || !result.photoUris || result.photoUris.length === 0) {
        console.info('PhotoCaptureService: camera capture returned no URI');
        return null;
      }

      const uri = result.photoUris[0];
      const photoResult = new PhotoResult();
      photoResult.uri = uri;
      photoResult.displayName = this.extractDisplayName(uri);
      console.info('PhotoCaptureService: camera capture success, uri=' + uri);
      return photoResult;
    } catch (error) {
      console.error('PhotoCaptureService: capturePhoto error:', error);
      return null;
    }
  }

  obtainPhotoToProcess(photoResult: PhotoResult): void {
    console.info(
      'PhotoCaptureService: obtainPhotoToProcess called, uri=' + photoResult.uri +
      ', displayName=' + photoResult.displayName
    );
  }

  private extractDisplayName(uri: string): string {
    if (!uri || uri.length === 0) {
      return '';
    }
    const lastSlash = uri.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < uri.length - 1) {
      return uri.substring(lastSlash + 1);
    }
    return uri;
  }
}

export const photoCaptureService = new PhotoCaptureService();
```

**关键说明**：

1. **`pickFromAlbum()`** -- 使用 `photoAccessHelper.PhotoViewPicker`，这是 HarmonyOS 6 (API 12+) 的安全控件模式 Picker，**不需要声明 `ohos.permission.READ_IMAGEVIDEO` 权限**。Picker 自己管理权限弹窗，用户在 Picker 内授权即可。

2. **`capturePhoto()`** -- 使用 `camera.CameraViewPicker`，这也是安全控件模式，拍照后自动存入系统相册，返回的 `photoUris` 即为存入相册后的 URI，**不需要单独声明相机权限**（安全控件模式下 Picker 自管理）。但如果实际设备测试发现需要额外权限，则在 `module.json5` 中补充。

3. **`obtainPhotoToProcess()`** -- 当前仅 console.log 输出。**后续对接要点**：其他同学只需修改此函数的实现，将 `photoResult.uri`（或从 uri 读取的图像数据）传入他们的处理逻辑。函数签名 `obtainPhotoToProcess(photoResult: PhotoResult)` 保持不变即可。

4. **单例导出** -- `export const photoCaptureService = new PhotoCaptureService()`，与项目中 `securePrefs` 的单例导出模式一致。

---

### 3.2 `pages/ImportPage.ets` -- 导入 Tab 页面 UI

**定位**：纯 UI 组件，遵循现有 Page 模式（`@Component` + `@ObjectLink viewModel` + `@StorageProp localeVersion`）。

**目录路径**：`entry/src/main/ets/pages/ImportPage.ets`

**完整代码设计**：

```typescript
import { MainViewModel } from '../viewmodel/MainViewModel';
import { PhotoResult, photoCaptureService } from '../service/PhotoCaptureService';

@Component
export struct ImportPage {
  @ObjectLink viewModel: MainViewModel;
  @StorageProp('localeVersion') localeVersion: number = 0;

  @State processingState: string = 'idle';
  @State photoUriState: string = '';
  @State errorState: string = '';

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.Header();
        this.ActionButtons();
        this.StatusSection();

        if (this.photoUriState.length > 0) {
          this.PhotoPreviewSection();
        }

        if (this.errorState.length > 0) {
          this.ErrorRail();
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
      Text(this.localizedText('import_header_eyebrow', 'IMPORT'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D5DD8');

      Text(this.localizedText('import_header_title', 'Import'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#17181C');

      Text(this.localizedText('import_header_subtitle', 'Take a photo or pick from album to import into OpenClaw.'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#4D5563');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder ActionButtons() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 4 }) {
          Text('📷')
            .fontSize(28);
          Text(this.localizedText('import_action_camera', 'Camera'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
      }
      .layoutWeight(1)
      .height(120)
      .backgroundColor('#1D5DD8')
      .borderRadius(16)
      .enabled(this.processingState === 'idle')
      .onClick(() => {
        this.handleCapturePhoto();
      });

      Button({ type: ButtonType.Normal }) {
        Column({ space: 4 }) {
          Text('🖼️')
            .fontSize(28);
          Text(this.localizedText('import_action_album', 'Album'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1D5DD8');
        }
      }
      .layoutWeight(1)
      .height(120)
      .backgroundColor('#ECF3FF')
      .borderRadius(16)
      .border({ width: 1, color: '#D5E2FA' })
      .enabled(this.processingState === 'idle')
      .onClick(() => {
        this.handlePickFromAlbum();
      });
    }
    .width('100%');
  }

  @Builder StatusSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('import_state_label', 'IMPORT STATE'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D5DD8');

      Column({ space: 12 }) {
        Row() {
          Text(this.importStateLabel())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.importStateTextColor());

          Blank();

          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(this.importStateTextColor());

            Text(this.importStateLabel())
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.importStateTextColor())
              .margin({ left: 6 });
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.importStateBgColor())
          .borderRadius(999)
          .border({ width: 1, color: this.importStateBorderColor() });
        }
        .width('100%');

        Text(this.importStateDescription())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4D5563');
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

  @Builder PhotoPreviewSection() {
    Column({ space: 12 }) {
      Text(this.localizedText('import_photo_label', 'SELECTED PHOTO'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D5DD8');

      Column({ space: 12 }) {
        Image(this.photoUriState)
          .width('100%')
          .height(200)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .backgroundColor('#F6F7FA');

        this.InfoRow(
          this.localizedText('import_photo_uri', 'Photo URI'),
          this.photoUriState.length > 60
            ? this.photoUriState.substring(0, 60) + '...'
            : this.photoUriState
        );
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

  @Builder ErrorRail() {
    Column({ space: 2 }) {
      Text(this.localizedText('import_error_title', 'IMPORT ERROR'))
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#DC2626');

      Text(this.errorState)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#17181C');
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#DC2626' });
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

  @Builder DividerLine() {
    Divider().color('#E5E7EC');
  }

  private handleCapturePhoto(): void {
    this.processingState = 'capturing';
    this.errorState = '';
    this.photoUriState = '';

    photoCaptureService.capturePhoto().then((result: PhotoResult | null) => {
      if (result && result.uri.length > 0) {
        this.photoUriState = result.uri;
        this.processingState = 'success';
        photoCaptureService.obtainPhotoToProcess(result);
      } else {
        this.processingState = 'idle';
      }
    }).catch((error: Error) => {
      this.processingState = 'error';
      this.errorState = error.message || this.localizedText('import_error_camera', 'Camera capture failed.');
    });
  }

  private handlePickFromAlbum(): void {
    this.processingState = 'picking';
    this.errorState = '';
    this.photoUriState = '';

    photoCaptureService.pickFromAlbum().then((result: PhotoResult | null) => {
      if (result && result.uri.length > 0) {
        this.photoUriState = result.uri;
        this.processingState = 'success';
        photoCaptureService.obtainPhotoToProcess(result);
      } else {
        this.processingState = 'idle';
      }
    }).catch((error: Error) => {
      this.processingState = 'error';
      this.errorState = error.message || this.localizedText('import_error_album', 'Album pick failed.');
    });
  }

  private importStateLabel(): string {
    switch (this.processingState) {
      case 'capturing':
        return this.localizedText('import_state_capturing', 'Capturing');
      case 'picking':
        return this.localizedText('import_state_picking', 'Picking');
      case 'success':
        return this.localizedText('import_state_success', 'Photo obtained');
      case 'error':
        return this.localizedText('import_state_error', 'Error');
      default:
        return this.localizedText('import_state_idle', 'Ready');
    }
  }

  private importStateDescription(): string {
    switch (this.processingState) {
      case 'capturing':
        return this.localizedText('import_reason_capturing', 'Camera is open. Take a photo and it will be saved to the album automatically.');
      case 'picking':
        return this.localizedText('import_reason_picking', 'Album picker is open. Select one photo to import.');
      case 'success':
        return this.localizedText('import_reason_success', 'A photo has been obtained and passed to obtainPhotoToProcess for further handling.');
      case 'error':
        return this.localizedText('import_reason_error', 'The last photo operation failed. Try again or use a different source.');
      default:
        return this.localizedText('import_reason_idle', 'Tap Camera to take a new photo, or Album to pick an existing one.');
    }
  }

  private importStateTextColor(): string {
    switch (this.processingState) {
      case 'capturing':
      case 'picking':
        return '#1D5DD8';
      case 'success':
        return '#2F8C5A';
      case 'error':
        return '#DC2626';
      default:
        return '#8A92A2';
    }
  }

  private importStateBgColor(): string {
    switch (this.processingState) {
      case 'capturing':
      case 'picking':
        return '#ECF3FF';
      case 'success':
        return '#E8F5EC';
      case 'error':
        return '#FFF5F5';
      default:
        return '#F6F7FA';
    }
  }

  private importStateBorderColor(): string {
    switch (this.processingState) {
      case 'capturing':
      case 'picking':
        return '#D5E2FA';
      case 'success':
        return '#BEE0CA';
      case 'error':
        return '#F3C8C8';
      default:
        return '#E5E7EC';
    }
  }

  private localizedText(name: string, fallback: string): string {
    try {
      void this.localeVersion;
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (error) {
      console.warn('ImportPage: localizedText failed for key: ' + name);
      return fallback;
    }
  }
}
```

**设计要点解析**：

1. **为什么保留 `@ObjectLink viewModel`？** -- 虽然导入 Tab 的核心功能不依赖 ViewModel，但所有现有 Page 都遵循此模式。保留它意味着：
   - ImportPage 可以从 viewModel 读取 `isConnected` 等连接状态来显示在页面上（如需要）
   - 与现有架构一致性，不破坏组件模式
   - 后续对接功能时可能需要通过 ViewModel 向 Gateway 发送照片数据

2. **本地状态 `processingState`** -- 使用状态码 `idle/capturing/picking/success/error`，与 VoicePage/ScreenPage 的状态码模式完全一致，复用相同的颜色映射体系。

3. **不注册监听器** -- ImportPage 的 `aboutToAppear/aboutToDisappear` 不需要注册监听器，因为照片获取是用户主动触发的一次性操作，不是持续监听的状态。这与 VoicePage/ScreenPage 的轻量级模式类似（它们也没有独立监听器）。

4. **`handleCapturePhoto/handlePickFromAlbum`** -- 异步操作，操作期间按钮 disabled（`this.processingState === 'idle'` 时才 enabled），防止重复触发。

5. **照片预览** -- 成功获取照片后，`photoUriState` 非空，显示 `Image(this.photoUriState)` 预览和 URI 信息。

---

## 四、现有文件修改设计

### 4.1 `PostOnboardingTabs.ets` -- 3处增量修改

**修改 1：顶部 import 区**

```diff
  import { MainViewModel } from '../viewmodel/MainViewModel';
  import { ConnectPage } from './ConnectPage';
  import { ChatPage } from './ChatPage';
  import { VoicePage } from './VoicePage';
  import { ScreenPage } from './ScreenPage';
  import { SettingsPage } from './SettingsPage';
+ import { ImportPage } from './ImportPage';
```

**修改 2：条件渲染区 -- 将最后的 `else` 改为 `else if (activeTab === 4)` + 新增 `else` 分支**

```diff
        } else if (this.activeTab === 3) {
          ScreenPage({ viewModel: this.viewModel });
-       } else {
+       } else if (this.activeTab === 4) {
          SettingsPage({ viewModel: this.viewModel });
+       } else {
+         ImportPage({ viewModel: this.viewModel });
        }
```

**修改 3：TabBar Builder 中新增 TabItem**

```diff
      this.TabItem(4, this.localizedText('tab_settings', 'Settings'), '⚙️');
+     this.TabItem(5, this.localizedText('tab_import', 'Import'), '📥');
```

**为什么不调整现有 Tab 索引？** -- 当前条件渲染用的是硬编码数字（0/1/2/3），Settings 是 `else`兜底=4。新增 Import 只需把兜底改成显式 `else if (activeTab === 4)` 然后新兜底 `else` 指向 ImportPage（index=5）。所有现有逻辑不受影响。

**syncTabSideEffects 不需要新增逻辑** -- ImportPage 不需要首次激活时的初始化动作（与 VoicePage/ScreenPage 不同），所以 `syncTabSideEffects()` 无需修改。

---

### 4.2 `module.json5` -- 权限声明

当前 `requestPermissions` 只有 INTERNET 和 GET_NETWORK_INFO。

HarmonyOS 6 (API 12+) 的 `PhotoViewPicker` 和 `CameraViewPicker` 在安全控件模式下**自动管理权限**，但为了兼容性和某些设备可能需要显式声明的情况，建议添加相机权限：

```diff
      {
        "name": "ohos.permission.GET_NETWORK_INFO",
        "reason": "$string:network_state_permission_reason",
        "usedScene": {
          "abilities": [
            "EntryAbility"
          ],
          "when": "inuse"
        }
+     },
+     {
+       "name": "ohos.permission.CAMERA",
+       "reason": "$string:camera_permission_reason",
+       "usedScene": {
+         "abilities": [
+           "EntryAbility"
+         ],
+         "when": "inuse"
+       }
      }
```

注意：`camera_permission_reason` 已在现有 string.json 中定义（base: "Required for camera capture functionality"，zh_CN: "摄像头捕获功能所需"，en_US: 同 base）。

如果实际测试中安全控件模式完全免权限声明，此条目可以移除，不影响功能。

---

### 4.3 `resources/base/element/string.json` -- 新增国际化 key

在现有 `tab_settings` 之后插入：

```json
    { "name": "tab_import", "value": "Import" },
    { "name": "import_header_eyebrow", "value": "IMPORT" },
    { "name": "import_header_title", "value": "Import" },
    { "name": "import_header_subtitle", "value": "Take a photo or pick from album to import into OpenClaw." },
    { "name": "import_action_camera", "value": "Camera" },
    { "name": "import_action_album", "value": "Album" },
    { "name": "import_state_label", "value": "IMPORT STATE" },
    { "name": "import_state_idle", "value": "Ready" },
    { "name": "import_state_capturing", "value": "Capturing" },
    { "name": "import_state_picking", "value": "Picking" },
    { "name": "import_state_success", "value": "Photo obtained" },
    { "name": "import_state_error", "value": "Error" },
    { "name": "import_reason_idle", "value": "Tap Camera to take a new photo, or Album to pick an existing one." },
    { "name": "import_reason_capturing", "value": "Camera is open. Take a photo and it will be saved to the album automatically." },
    { "name": "import_reason_picking", "value": "Album picker is open. Select one photo to import." },
    { "name": "import_reason_success", "value": "A photo has been obtained and passed to obtainPhotoToProcess for further handling." },
    { "name": "import_reason_error", "value": "The last photo operation failed. Try again or use a different source." },
    { "name": "import_error_title", "value": "IMPORT ERROR" },
    { "name": "import_error_camera", "value": "Camera capture failed." },
    { "name": "import_error_album", "value": "Album pick failed." },
    { "name": "import_photo_label", "value": "SELECTED PHOTO" },
    { "name": "import_photo_uri", "value": "Photo URI" }
```

### 4.4 `resources/zh_CN/element/string.json` -- 中文翻译

```json
    { "name": "tab_import", "value": "导入" },
    { "name": "import_header_eyebrow", "value": "导入" },
    { "name": "import_header_title", "value": "导入" },
    { "name": "import_header_subtitle", "value": "拍照或从相册选取照片导入到 OpenClaw。" },
    { "name": "import_action_camera", "value": "拍照" },
    { "name": "import_action_album", "value": "相册" },
    { "name": "import_state_label", "value": "导入状态" },
    { "name": "import_state_idle", "value": "就绪" },
    { "name": "import_state_capturing", "value": "拍照中" },
    { "name": "import_state_picking", "value": "选取中" },
    { "name": "import_state_success", "value": "照片已获取" },
    { "name": "import_state_error", "value": "错误" },
    { "name": "import_reason_idle", "value": "点击拍照拍摄新照片，或点击相册选取已有照片。" },
    { "name": "import_reason_capturing", "value": "相机已打开。拍一张照片后会自动存入相册。" },
    { "name": "import_reason_picking", "value": "相册选取器已打开。选择一张照片进行导入。" },
    { "name": "import_reason_success", "value": "照片已获取并传入 obtainPhotoToProcess 进行后续处理。" },
    { "name": "import_reason_error", "value": "上一次照片操作失败。请重试或使用其他来源。" },
    { "name": "import_error_title", "value": "导入错误" },
    { "name": "import_error_camera", "value": "拍照失败。" },
    { "name": "import_error_album", "value": "相册选取失败。" },
    { "name": "import_photo_label", "value": "已选照片" },
    { "name": "import_photo_uri", "value": "照片 URI" }
```

### 4.5 `resources/en_US/element/string.json` -- 英文翻译

与 base 相同（已在 4.3 中列出），逐条复制即可。

---

## 五、架构一致性验证

| 维度 | 现有模式 | ImportPage 是否遵循 |
|------|----------|---------------------|
| 装饰器 | `@Component` + `@ObjectLink viewModel` + `@StorageProp localeVersion` | 是 |
| Header 模式 | eyebrow(12px蓝粗) + title(24px黑粗) + subtitle(14px灰中) | 是 |
| 卡片样式 | padding(14) + bg(#FFFFFF) + borderRadius(14) + border(#E5E7EC) | 是 |
| 状态码体系 | stateCode + label + description + textColor + bgColor + borderColor | 是 |
| 颜色映射 | 绿/蓝/黄/红/灰 5 色系 | 是（capturing/picking=蓝, success=绿, error=红, idle=灰） |
| 国际化 | localizedText(name, fallback) + @StorageProp localeVersion | 是 |
| 监听器 | 可选（VoicePage/ScreenPage 无独立监听器） | 无独立监听器（与 ScreenPage 同模式） |
| 服务层 | GatewaySession(api层) + SecurePrefs(common层) | PhotoCaptureService(service层) -- 新增目录，与 api 同级 |

---

## 六、后续对接指南

### 6.1 其他同学对接 `obtainPhotoToProcess`

当前实现（`PhotoCaptureService.ets`）：

```typescript
obtainPhotoToProcess(photoResult: PhotoResult): void {
  console.info(
    'PhotoCaptureService: obtainPhotoToProcess called, uri=' + photoResult.uri +
    ', displayName=' + photoResult.displayName
  );
}
```

对接时，其他同学只需修改此函数体，将 `photoResult.uri`（或从 uri 读取图像二进制数据）传入他们的处理逻辑。**函数签名不变**，`PhotoResult` 类型已包含 `uri` 和 `displayName`。

如果对接逻辑是异步的，可以将返回类型改为 `Promise<void>`：

```typescript
async obtainPhotoToProcess(photoResult: PhotoResult): Promise<void> {
  const imageData = await this.readImageFromUri(photoResult.uri);
  await theirProcessingFunction(imageData);
}
```

ImportPage 调用处也相应改为 `await` 或 `.then()` 即可。

### 6.2 如果需要在 Gateway 上发送照片

后续如果 `obtainPhotoToProcess` 需要通过 Gateway 发送照片数据，只需在 ImportPage 中引入 ViewModel 的 operatorSession：

```typescript
// 未来可能的方向（当前不实现）
private handleSendToGateway(photoResult: PhotoResult): void {
  if (!this.viewModel.isConnected || !this.viewModel.operatorSession) {
    this.errorState = 'Connect to a gateway before sending photos.';
    return;
  }
  // 通过 operatorSession.request('photo.upload', ...) 发送
}
```

此时 MainViewModel 需要暴露 operatorSession 的 request 方法（当前是 private），这是一个后续改动点，**当前阶段不做**。

---

## 七、实际文件树（新增后）

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets              # 不改动
├── pages/
│   ├── Index.ets                     # 不改动
│   ├── OnboardingPage.ets            # 不改动
│   ├── PostOnboardingTabs.ets        # ★ 3处增量修改
│   ├── ConnectPage.ets               # 不改动
│   ├── ChatPage.ets                  # 不改动
│   ├── VoicePage.ets                 # 不改动
│   ├── ScreenPage.ets                # 不改动
│   ├── SettingsPage.ets              # 不改动
│   ├── ImportPage.ets                # ★ 新增
├── viewmodel/
│   └── MainViewModel.ets             # 不改动
├── model/
│   └── GatewayModels.ets             # 不改动
├── api/
│   ├── GatewaySession.ets            # 不改动
│   ├── IdentityStore.ets             # 不改动
│   ├── DeviceIdentityStore.ets       # 不改动
│   ├── DeviceAuthStore.ets           # 不改动
│   ├── DeviceAuthPayload.ets         # 不改动
├── service/
│   └── PhotoCaptureService.ets       # ★ 新增
├── common/
│   └── SecurePrefs.ets               # 不改动
├── node/
│   ├── InvokeCommandRegistry.ets     # 不改动
│   ├── NodeInvokeDispatcher.ets      # 不改动
└── protocol/
    └── OpenClawProtocolConstants.ets # 不改动
```

---

## 八、实施顺序

1. 创建 `entry/src/main/ets/service/PhotoCaptureService.ets`
2. 创建 `entry/src/main/ets/pages/ImportPage.ets`
3. 修改 `entry/src/main/ets/pages/PostOnboardingTabs.ets`（3处增量）
4. 修改 `entry/src/main/module.json5`（新增 CAMERA 权限）
5. 修改 `resources/base/element/string.json`（新增国际化 key）
6. 修改 `resources/zh_CN/element/string.json`（新增中文翻译）
7. 修改 `resources/en_US/element/string.json`（新增英文翻译）
8. 编译验证 -- `pnpm build` 或 DevEco Studio 构建
9. 真机/模拟器测试 -- 验证拍照、相册选取、console.log 输出