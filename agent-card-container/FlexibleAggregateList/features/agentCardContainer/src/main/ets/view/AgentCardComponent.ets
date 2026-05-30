import { CardData } from '../model/CardData';
import { commonConstants } from '../constants/CommonConstants';

@Component
export struct AgentCardComponent {
  @Prop cardData: CardData = new CardData(0, '', '', undefined, undefined, '');
  onButtonClick: (cardNumber: number) => void = () => {};

  build() {
    Column() {
      Text(this.cardData.title)
        .fontSize(commonConstants.TITLE_FONT_SIZE)
        .fontWeight(commonConstants.TITLE_FONT_WEIGHT)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .margin({ bottom: 8 })

      Text(this.cardData.line0)
        .fontSize(commonConstants.LINE_FONT_SIZE)
        .fontWeight(commonConstants.LINE_FONT_WEIGHT)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .margin({ bottom: 4 })

      if (this.cardData.line1 && this.cardData.line1.length > 0) {
        Text(this.cardData.line1)
          .fontSize(commonConstants.LINE_FONT_SIZE)
          .fontWeight(commonConstants.LINE_FONT_WEIGHT)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .width('100%')
          .margin({ bottom: 8 })
      }

      if (this.cardData.buttonText && this.cardData.buttonText.length > 0) {
        Row() {
          Button(this.cardData.buttonText)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
            .borderRadius(8)
            .height(36)
            .onClick(() => {
              this.onButtonClick(this.cardData.number);
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(commonConstants.CARD_BORDER_RADIUS)
    .backgroundColor(Color.White)
  }
}