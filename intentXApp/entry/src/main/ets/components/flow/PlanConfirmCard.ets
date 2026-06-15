import { PlanItem, UIBlock } from '../../model/FlowModels';
import { FlowColors } from '../../common/FlowColors';

/**
 * PlanConfirmCard —— 个性化任务创建 / 计划确认（01 文档 §3.4）。
 * 「确认创建」发送 "可以"；「修改」聚焦输入框。
 */
@Component
export struct PlanConfirmCard {
  @ObjectLink block: UIBlock;
  @Prop isLocked: boolean = false;
  @Prop canInteract: boolean = true;
  onConfirm: () => void = () => {};
  onModify: () => void = () => {};

  build() {
    Column() {
      // 头部徽章
      Row() {
        Text('个性化任务创建')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(FlowColors.TEAL_FG)
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
          .backgroundColor(FlowColors.TEAL_BG)
          .borderRadius(999);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .borderWidth({ bottom: 1 })
      .borderColor(FlowColors.BORDER_SOFT);

      Text(`任务：${this.block.taskTitle}`)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(FlowColors.FOREGROUND)
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 });

      Column({ space: 10 }) {
        ForEach(this.block.items, (item: PlanItem, i: number) => {
          Row({ space: 10 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle().width(18).height(18).fill(FlowColors.MUTED);
              Text(`${i + 1}`)
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(FlowColors.MUTED_FG);
            }
            .width(18)
            .height(18)
            .margin({ top: 1 });

            Column({ space: 2 }) {
              Text(item.label)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(FlowColors.FOREGROUND)
                .width('100%');
              Text(item.value)
                .fontSize(12)
                .fontColor(FlowColors.MUTED_FG)
                .lineHeight(18)
                .width('100%');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        }, (item: PlanItem, i: number) => `${i}|${item.label}`);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 });

      // 底部确认 / 已确认态
      Column() {
        if (this.block.approved || this.isLocked) {
          Row({ space: 6 }) {
            Text('✓').fontSize(14).fontColor(FlowColors.STEP_DONE);
            Text('已确认创建')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(FlowColors.STEP_DONE);
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 });
        } else {
          Text(this.block.question)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(FlowColors.FOREGROUND)
            .width('100%')
            .padding({ left: 16, right: 16, top: 12 });

          Row({ space: 10 }) {
            Button({ type: ButtonType.Normal }) {
              Text('修改')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(FlowColors.FOREGROUND);
            }
            .layoutWeight(1)
            .height(42)
            .borderRadius(12)
            .backgroundColor(FlowColors.MUTED)
            .enabled(this.canInteract)
            .onClick(() => {
              this.onModify();
            });

            Button({ type: ButtonType.Normal }) {
              Text('确认创建')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF');
            }
            .layoutWeight(1)
            .height(42)
            .borderRadius(12)
            .backgroundColor(FlowColors.AGENT_BLUE)
            .enabled(this.canInteract)
            .onClick(() => {
              this.onConfirm();
            });
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 14 });
        }
      }
      .width('100%')
      .borderWidth({ top: 1 })
      .borderColor(FlowColors.BORDER_SOFT);
    }
    .width('100%')
    .backgroundColor(FlowColors.CARD)
    .borderRadius(16)
    .border({ width: 1, color: FlowColors.BORDER })
    .clip(true);
  }
}
