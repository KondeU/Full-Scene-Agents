import { MainViewModel } from '../viewmodel/MainViewModel';
import { PhotoResult, photoCaptureService } from '../service/PhotoCaptureService';

@Component
export struct ImportPage {
  @ObjectLink viewModel: MainViewModel;
  @StorageProp('localeVersion') localeVersion: number = 0;

  @State processingState: string = 'idle';
  @State photoUriState: string = '';
  @State errorState: string = '';

  aboutToAppear(): void {
    this.resetPageState();
  }

  aboutToDisappear(): void {
    // ImportPage 不注册任何监听器，无需清理。
    // 保留此方法占位以符合页面生命周期约定，便于后续扩展。
  }

  private resetPageState(): void {
    this.processingState = 'idle';
    this.photoUriState = '';
    this.errorState = '';
  }

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
