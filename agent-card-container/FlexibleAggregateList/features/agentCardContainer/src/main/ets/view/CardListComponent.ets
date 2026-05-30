import { CardData } from '../model/CardData';
import { AgentCardComponent } from './AgentCardComponent';
import { commonConstants } from '../constants/CommonConstants';

@Component
export struct CardListComponent {
  @Prop cardList: CardData[] = [];
  onButtonClick: (cardNumber: number) => void = () => {};

  build() {
    Column() {
      if (this.cardList.length === 0) {
        Column() {
          Text(commonConstants.EMPTY_TEXT_CARD)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.cardList, (card: CardData) => {
            ListItem() {
              AgentCardComponent({
                cardData: card,
                onButtonClick: this.onButtonClick
              })
            }
            .margin({ bottom: commonConstants.CARD_GAP })
          }, (card: CardData) => card.number.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
  }
}