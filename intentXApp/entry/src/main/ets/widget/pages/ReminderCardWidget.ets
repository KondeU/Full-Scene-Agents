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
      // ── 左侧文字区 ──
      Column() {
        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(14).fontWeight(400).fontColor('#99000000')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 10 });
        }

        Text(this.body)
          .fontSize(17).fontWeight(500).fontColor('#E5000000')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(22);

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

      // ── 右侧图片区 ──
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
      // 底层背景
      if (this.hasImageStr === 'true') {
        Image('memory://' + this.imgSrc)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(16)
          .alt($r('app.media.icon'));
      } else {
        // 无图：白色背景
        Column()
          .width('100%').height('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
      }

      // body 文字 — 左上角，略微右移下移
      Column() {
        Text(this.body)
          .fontSize(20).fontWeight(500).fontColor('#E5000000')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(26)
      }
      .width('100%').height('100%')
      .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
      .padding({ left: 26, top: 18, right: 88 })

      // 右侧按钮组
      Row() {
        Blank()
        Column({ space: 8 }) {
          // 📷 拍一拍
          Column({ space: 2 }) {
            Text('📷').fontSize(22)
            Text('拍一拍')
              .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#1D5DD8')
          }
          .width(60).height(60)
          .borderRadius(14)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#B3ECF3FF')
          .border({ width: 1, color: '#B3D5E2FA' })
          .onClick(() => {
            postCardAction(this, {
              action: 'router', abilityName: 'EntryAbility',
              params: { targetPage: 'import', importAction: 'camera' }
            });
          });

          // 🖼️ 选一选
          Column({ space: 2 }) {
            Text('🖼️').fontSize(22)
            Text('选一选')
              .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#1D5DD8')
          }
          .width(60).height(60)
          .borderRadius(14)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#B3ECF3FF')
          .border({ width: 1, color: '#B3D5E2FA' })
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
  }
}
