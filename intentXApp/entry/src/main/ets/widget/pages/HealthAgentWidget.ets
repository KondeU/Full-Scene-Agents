let storage = new LocalStorage();

interface TrendPoint {
  x: number;
  y: number;
}

@Entry(storage)
@Component
struct OpenClawWidget {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('weightValue') weightValue: string = '61.5';
  @LocalStorageProp('bloodPressureValue') bloodPressureValue: string = '117';

  readonly ACTION_TYPE: string = 'router';
  readonly ABILITY_NAME: string = 'EntryAbility';
  readonly FULL_SIZE: string = '100%';
  readonly weightPoints: TrendPoint[] = [
    { x: 0, y: 18 },
    { x: 18, y: 20 },
    { x: 36, y: 17 },
    { x: 54, y: 24 },
    { x: 72, y: 30 },
    { x: 90, y: 28 },
    { x: 108, y: 34 }
  ];
  readonly bloodPressurePoints: TrendPoint[] = [
    { x: 0, y: 22 },
    { x: 18, y: 14 },
    { x: 36, y: 18 },
    { x: 54, y: 10 },
    { x: 72, y: 20 },
    { x: 90, y: 16 },
    { x: 108, y: 25 }
  ];

  build() {
    Row({ space: 12 }) {
      this.EntryNotebookCard();

      Column({ space: 6 }) {
        Row() {
          Text('本周健康周报')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .maxLines(1);

          Blank();

          Text('查看全部 >')
            .fontSize(11)
            .fontColor('#8AA6BD')
            .maxLines(1);
        }
        .width(this.FULL_SIZE)
        .alignItems(VerticalAlign.Center);

        this.MetricCard('体重', this.weightValue, 'kg', '#2B6CB0', '#6B8FAB', '#9BB3C7', '#E9F6FF', '#DCEFFF', this.weightPoints);
        this.MetricCard('血压', this.bloodPressureValue, 'mmHg', '#D6536D', '#B08A90', '#C79BAB', '#FFEEF0', '#FFE2E6', this.bloodPressurePoints);
      }
      .layoutWeight(1)
      .height(this.FULL_SIZE)
      .justifyContent(FlexAlign.SpaceBetween);
    }
    .width(this.FULL_SIZE)
    .height(this.FULL_SIZE)
    .padding(12)
    .borderRadius(24)
    .linearGradient({
      angle: 180,
      colors: [['#FFFFFF', 0.0], ['#F5FAFD', 1.0]]
    })
    .shadow({ radius: 30, color: '#3878AAD2', offsetX: 0, offsetY: 10 })
    .onClick(() => {
      this.openApp('health_widget');
    });
  }

  @Builder
  EntryNotebookCard() {
    Column() {
      Stack() {
        Column()
          .width(26)
          .height(30)
          .borderRadius({ bottomLeft: 8, bottomRight: 8 })
          .linearGradient({
            angle: 180,
            colors: [['#8FD9D6', 0.0], ['#B8E8E4', 1.0]]
          })
          .position({ x: 84, y: -2 });

        Button() {
          Image($r('app.media.cartoon_camera'))
            .width(44)
            .height(44)
            .objectFit(ImageFit.Contain);
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 22, color: '#615F96C8', offsetX: 0, offsetY: 12 })
        .position({ x: 34, y: 26 })
        .onClick(() => {
          this.sendWidgetMessage('capture_health_data');
        });

        Text('录入健康数据')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .textAlign(TextAlign.Center)
          .lineHeight(22)
          .width(100)
          .position({ x: 16, y: 102 });

        Column()
          .width(40)
          .height(40)
          .borderRadius({ bottomRight: 18 })
          .linearGradient({
            angle: 135,
            colors: [['#00FFFFFF', 0.0], ['#33FFFFFF', 0.5], ['#DCECF6', 1.0]]
          })
          .position({ x: 92, y: 128 });

        Column()
          .width(30)
          .height(30)
          .borderRadius({ bottomRight: 18 })
          .linearGradient({
            angle: 135,
            colors: [['#00FFFFFF', 0.0], ['#F3FAFC', 0.55], ['#DCECF6', 1.0]]
          })
          .shadow({ radius: 6, color: '#381E5478', offsetX: -3, offsetY: -3 })
          .position({ x: 102, y: 138 });
      }
      .width(132)
      .height(this.FULL_SIZE);
    }
    .width(132)
    .height(this.FULL_SIZE)
    .borderRadius(18)
    .linearGradient({
      angle: 160,
      colors: [['#D6F0F5', 0.0], ['#CFEAF6', 0.45], ['#C4E4F7', 1.0]]
    })
    .shadow({ radius: 14, color: '#2E78B4DC', offsetX: 0, offsetY: 4 })
    .clip(true);
  }

  @Builder
  MetricCard(label: string, value: string, unit: string, accent: string, labelColor: string, unitColor: string, topColor: string, bottomColor: string, points: TrendPoint[]) {
    Column() {
      Row() {
        Text(label)
          .fontSize(10)
          .fontColor(labelColor)
          .maxLines(1);

        Blank();

        Row({ space: 2 }) {
          Text(value)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(accent)
            .maxLines(1);

          Text(unit)
            .fontSize(9)
            .fontColor(unitColor)
            .maxLines(1);
        }
        .alignItems(VerticalAlign.Bottom);
      }
      .width(this.FULL_SIZE)
      .alignItems(VerticalAlign.Bottom);

      this.TrendLine(accent, points);
    }
    .width(this.FULL_SIZE)
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 6, bottom: 5 })
    .borderRadius(12)
    .linearGradient({
      angle: 150,
      colors: [[topColor, 0.0], [bottomColor, 1.0]]
    });
  }

  @Builder
  TrendLine(color: string, points: TrendPoint[]) {
    Stack() {
      ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
        Row()
          .width(this.segmentWidth(points[index], points[index + 1]))
          .height(2)
          .borderRadius(1)
          .backgroundColor(color)
          .rotate({ angle: this.segmentAngle(points[index], points[index + 1]) })
          .position({
            x: this.segmentX(points[index], points[index + 1]),
            y: this.segmentY(points[index], points[index + 1])
          });
      });
    }
    .width(this.FULL_SIZE)
    .height(34)
    .margin({ top: 1 });
  }

  private sendWidgetMessage(action: string): void {
    postCardAction(this, {
      action: 'message',
      params: {
        action: action,
        formId: this.formId
      }
    });
  }

  private openApp(source: string): void {
    postCardAction(this, {
      action: this.ACTION_TYPE,
      abilityName: this.ABILITY_NAME,
      params: {
        message: source
      }
    });
  }

  private segmentWidth(start: TrendPoint, end: TrendPoint): number {
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  private segmentAngle(start: TrendPoint, end: TrendPoint): number {
    return Math.atan2(end.y - start.y, end.x - start.x) * 180 / Math.PI;
  }

  private segmentX(start: TrendPoint, end: TrendPoint): number {
    return (start.x + end.x - this.segmentWidth(start, end)) / 2;
  }

  private segmentY(start: TrendPoint, end: TrendPoint): number {
    return (start.y + end.y) / 2;
  }
}
