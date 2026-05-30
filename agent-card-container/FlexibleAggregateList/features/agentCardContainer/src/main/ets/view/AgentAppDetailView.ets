import { webview } from '@kit.ArkWeb';
import { CardData } from '../model/CardData';
import { CardListComponent } from './CardListComponent';
import { ImageImportComponent } from './ImageImportComponent';
import { commonConstants } from '../constants/CommonConstants';

@Component
export struct AgentAppDetailView {
  @State cardList: CardData[] = [];
  @State agentAppName: string = '';
  @State agentAppPath: string = '';
  @State currentTab: number = 0;
  private webController: webview.WebviewController = new webview.WebviewController();
  onRefresh: () => void = () => {};
  onBack: () => void = () => {};
  onActionClick: (cardNumber: number) => void = () => {};
  onImageSelected: (imageUri: string) => void = () => {};

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('sys.color.titlebar_icon_color')])
          .onClick(() => {
            this.onBack();
          })
        Text(this.agentAppName)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(24)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          .onClick(() => {
            this.onRefresh();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Web({ src: 'about:blank', controller: this.webController })
        .width('0px')
        .height('0px')
        .visibility(Visibility.None)

      Tabs({ index: this.currentTab }) {
        TabContent() {
          CardListComponent({
            cardList: this.cardList,
            onButtonClick: this.onActionClick
          })
        }
        .tabBar('卡片列表')

        TabContent() {
          ImageImportComponent({
            onImageSelected: this.onImageSelected
          })
        }
        .tabBar('图片导入')
      }
      .layoutWeight(1)
      .barPosition(BarPosition.End)
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}