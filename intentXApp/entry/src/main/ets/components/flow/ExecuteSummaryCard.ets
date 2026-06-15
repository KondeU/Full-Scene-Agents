import { UIBlock } from '../../model/FlowModels';
import { FlowColors } from '../../common/FlowColors';

/**
 * ExecuteSummaryCard —— 执行技能 / 结果汇总（01 文档 §3.6）。
 * 绿色完成头部 → 技能文件列表 → 用法编号列表 → 主 CTA。
 */
@Component
export struct ExecuteSummaryCard {
  @ObjectLink block: UIBlock;
  @Prop canInteract: boolean = true;
  onCta: () => void = () => {};

  private ctaLabel(): string {
    return this.block.cta.length > 0 ? '发一张健康截图试试' : '试试这个技能';
  }

  build() {
    Column() {
      // 绿色完成头部
      Row({ space: 8 }) {
        Text('✓')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(FlowColors.SUMMARY_FG);
        Text('技能已创建')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(FlowColors.SUMMARY_FG);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(FlowColors.SUMMARY_BG);

      if (this.block.intro.length > 0) {
        Text(this.block.intro)
          .fontSize(13)
          .fontColor(FlowColors.FOREGROUND)
          .lineHeight(20)
          .width('100%')
          .padding({ left: 16, right: 16, top: 10 });
      }

      // 技能文件路径
      Column({ space: 6 }) {
        ForEach(this.block.skillPaths, (p: string) => {
          Text(p)
            .fontSize(11)
            .fontFamily('monospace')
            .fontColor(FlowColors.MUTED_FG)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(FlowColors.MUTED)
            .borderRadius(8);
        }, (p: string) => p);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 });

      // 用法
      Column({ space: 6 }) {
        Text('用法')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(FlowColors.FOREGROUND)
          .width('100%');

        ForEach(this.block.usageSteps, (s: string, i: number) => {
          Row({ space: 8 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle().width(16).height(16).fill(FlowColors.AGENT_BLUE_LIGHT);
              Text(`${i + 1}`)
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(FlowColors.AGENT_BLUE);
            }
            .width(16)
            .height(16)
            .margin({ top: 1 });

            Text(s)
              .fontSize(12)
              .fontColor(FlowColors.MUTED_FG)
              .lineHeight(18)
              .layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        }, (s: string, i: number) => `${i}`);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .borderWidth({ top: 1 })
      .borderColor(FlowColors.BORDER_SOFT);

      if (this.block.cta.length > 0) {
        Button({ type: ButtonType.Normal }) {
          Text(this.ctaLabel())
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
        .width('100%')
        .height(44)
        .borderRadius(12)
        .backgroundColor(FlowColors.AGENT_BLUE)
        .margin({ left: 16, right: 16 })
        .enabled(this.canInteract)
        .onClick(() => {
          this.onCta();
        });
        Blank().height(14);
      }
    }
    .width('100%')
    .backgroundColor(FlowColors.CARD)
    .borderRadius(16)
    .border({ width: 1, color: FlowColors.BORDER })
    .clip(true);
  }
}
