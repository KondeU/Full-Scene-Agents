import { SkillStep, UIBlock } from '../../model/FlowModels';
import { FlowColors } from '../../common/FlowColors';

/**
 * SkillCreateCard —— 技能创建 / 文件写入进度（01 文档 §3.5）。
 * 错误行默认折叠，点击展开 Terminal 风格原始输出。错误不打断流程。
 */
@Component
export struct SkillCreateCard {
  @ObjectLink block: UIBlock;
  @State expandedId: string = '';

  private doneCount(): number {
    let n = 0;
    for (let i = 0; i < this.block.steps.length; i++) {
      if (this.block.steps[i].status === 'done') {
        n++;
      }
    }
    return n;
  }

  build() {
    Column() {
      // 头部徽章 + 计数
      Row() {
        Row({ space: 5 }) {
          Text('📄')
            .fontSize(11);
          Text('技能创建')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(FlowColors.TEAL_FG);
        }
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        .backgroundColor(FlowColors.TEAL_BG)
        .borderRadius(999);

        Blank();

        Text(`${this.doneCount()}/${this.block.steps.length}`)
          .fontSize(12)
          .fontColor(FlowColors.MUTED_FG);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .borderWidth({ bottom: 1 })
      .borderColor(FlowColors.BORDER_SOFT);

      Column() {
        ForEach(this.block.steps, (step: SkillStep) => {
          this.StepRow(step);
        }, (step: SkillStep) => step.id);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 4 });

      if (this.block.annotations.length > 0) {
        Column({ space: 2 }) {
          ForEach(this.block.annotations, (a: string, i: number) => {
            Text(a)
              .fontSize(12)
              .fontStyle(FontStyle.Italic)
              .fontColor(FlowColors.MUTED_FG)
              .lineHeight(18)
              .width('100%');
          }, (a: string, i: number) => `${i}`);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 10 })
        .borderWidth({ top: 1 })
        .borderColor(FlowColors.BORDER_SOFT);
      }
    }
    .width('100%')
    .backgroundColor(FlowColors.CARD)
    .borderRadius(16)
    .border({ width: 1, color: FlowColors.BORDER })
    .clip(true);
  }

  @Builder StepRow(step: SkillStep) {
    Column() {
      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(18)
            .height(18)
            .fill(step.status === 'done' ? FlowColors.STEP_DONE : FlowColors.STEP_ERROR);
          Text(step.status === 'done' ? '✓' : '✕')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
        .width(18)
        .height(18);

        Text(step.label)
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor(step.status === 'error' ? FlowColors.STEP_ERROR : FlowColors.FOREGROUND)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (step.detail.length > 0) {
          Text(this.expandedId === step.id ? '▲' : '▼')
            .fontSize(10)
            .fontColor(FlowColors.MUTED_FG);
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: 10, bottom: 10 })
      .onClick(() => {
        if (step.detail.length === 0) {
          return;
        }
        this.expandedId = this.expandedId === step.id ? '' : step.id;
      });

      if (this.expandedId === step.id && step.detail.length > 0) {
        Text(step.detail)
          .fontSize(10)
          .fontFamily('monospace')
          .fontColor(FlowColors.TERMINAL_FG)
          .lineHeight(16)
          .width('100%')
          .padding(10)
          .margin({ bottom: 8 })
          .backgroundColor(FlowColors.TERMINAL_BG)
          .borderRadius(8);
      }
    }
    .width('100%')
    .borderWidth({ bottom: 1 })
    .borderColor(FlowColors.BORDER_SOFT);
  }
}
