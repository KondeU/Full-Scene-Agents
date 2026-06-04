@Entry
@Component
struct ReminderCardWidget {
  @State title: string = '';
  @State body: string = '当前无主动提醒';
  @State note: string = '';
  @State imageUrl: string = '';
  @State hasImage: boolean = false;
  @State hasNote: boolean = false;

  build() {
    Row() {
      Column() {
        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#17181C')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }

        Text(this.body)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4D5563')
          .maxLines(this.hasImage ? 3 : 5)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (this.hasNote) {
          Text(this.note)
            .fontSize(10)
            .fontWeight(FontWeight.Normal)
            .fontColor('#8A92A2')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
      }
      .layoutWeight(this.hasImage ? 1 : 0)
      .width(this.hasImage ? '60%' : '100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 4, top: 10, bottom: 10 });

      if (this.hasImage) {
        Image(this.imageUrl)
          .width('38%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .margin({ right: 12 })
          .alt($r('app.media.icon'));
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F4FA')
    .borderRadius(16)
  }
}
