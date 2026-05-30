import { AgentAppEntry } from '../model/AgentAppEntry';
import { commonConstants } from '../constants/CommonConstants';

@Component
export struct AgentAppListComponent {
  @Prop agentAppList: AgentAppEntry[] = [];
  onItemClick: (entry: AgentAppEntry) => void = () => {};
  onRefresh: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text('AgentCards')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(24)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          .onClick(() => {
            this.onRefresh();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.agentAppList.length === 0) {
        Column() {
          Text(commonConstants.EMPTY_TEXT_AGENT_APP)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.agentAppList, (entry: AgentAppEntry) => {
            ListItem() {
              Row() {
                Text(entry.appName)
                  .fontSize(16)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .fontWeight(FontWeight.Medium)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .borderRadius(12)
              .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))
              .margin({ bottom: 8 })
              .onClick(() => {
                this.onItemClick(entry);
              })
            }
          }, (entry: AgentAppEntry) => entry.dirName)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}