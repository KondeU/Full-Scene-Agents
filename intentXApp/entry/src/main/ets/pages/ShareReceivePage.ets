import { UIExtensionContentSession } from '@kit.AbilityKit';

@Entry
@Component
struct ShareReceivePage {
  @StorageProp('shareReceiveStatus') status: string = 'sending';
  @StorageProp('shareReceiveUri') shareUri: string = '';
  @StorageProp('shareReceiveError') errorMsg: string = '';
  @StorageProp('localeVersion') localeVersion: number = 0;

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
      // 点击任意位置关闭面板（仅在结束状态）
      if (this.status === 'success' || this.status === 'fail') {
        const session = AppStorage.get<UIExtensionContentSession>('shareSession');
        if (session) {
          session.terminateSelf();
        }
      }
    });
  }
}
