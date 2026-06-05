let storage = new LocalStorage();

@Entry(storage)
@Component
struct ReminderCardWidget {
  @LocalStorageProp('title') title: string = '';
  @LocalStorageProp('body') body: string = '当前无主动提醒';
  @LocalStorageProp('note') note: string = '';
  @LocalStorageProp('imgSrc') imgSrc: string = '';
  @LocalStorageProp('hasImage') hasImageStr: string = 'false';

  build() {
    Row() {
      // ── 左侧文字区 ──
      Column() {
        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(14).fontWeight(500).fontColor('#E5000000')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 6 });
        }

        Text(this.body)
          .fontSize(12).fontWeight(400).fontColor('#99000000')
          .maxLines(this.hasImageStr === 'true' ? 3 : 5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(18);

        if (this.note.length > 0) {
          Text(this.note)
            .fontSize(10).fontWeight(400).fontColor('#66000000')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 });
        }
      }
      .layoutWeight(this.hasImageStr === 'true' ? 1 : 0)
      .width(this.hasImageStr === 'true' ? '60%' : '100%')
      .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
      .padding({ left: 14, right: this.hasImageStr === 'true' ? 8 : 14, top: 14, bottom: 14 });

      // ── 右侧图片区 ──
      if (this.hasImageStr === 'true') {
        Image('memory://' + this.imgSrc)
          .width(56).height(56)
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
        params: { targetPage: 'debug' }
      });
    });
  }
}
