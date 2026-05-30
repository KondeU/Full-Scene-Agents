import { CardData } from '../model/CardData';
import { AgentAppConfig } from '../model/AgentAppConfig';
import { CardListViewModel } from '../viewmodel/CardListViewModel';
import { ScriptExecutor } from '../viewmodel/ScriptExecutor';
import { commonConstants } from '../constants/CommonConstants';
import { picker } from '@kit.CoreFileKit';
import { common, Want } from '@kit.AbilityKit';
import { Logger } from '@ohos/common';

const logger = new Logger();
const TAG = 'AgentAppDetailPage';

class DetailPageParams {
  dirName: string = '';
  fullPath: string = '';
  appName: string = '';
}

@Entry
@Component
struct AgentAppDetailPage {
  @State cardList: CardData[] = [];
  @State agentAppName: string = '';
  @State agentAppPath: string = '';
  @State currentTab: number = 0;
  @State previewImageUri: string = '';
  private viewModel: CardListViewModel = new CardListViewModel();
  private scriptExecutor: ScriptExecutor = new ScriptExecutor();

  aboutToAppear(): void {
    const params: object = this.getUIContext().getRouter().getParams();
    if (params) {
      const p: DetailPageParams = new DetailPageParams();
      p.dirName = (params as Record<string, string>)['dirName'] ?? '';
      p.fullPath = (params as Record<string, string>)['fullPath'] ?? '';
      p.appName = (params as Record<string, string>)['appName'] ?? '';
      this.agentAppName = p.appName;
      this.agentAppPath = p.fullPath;
    }
    this.refreshCards();
  }

  onPageShow(): void {
    this.refreshCards();
  }

  private refreshCards(): void {
    this.cardList = this.viewModel.getCardList(this.agentAppPath);
  }

  private handleActionClick(cardNumber: number): void {
    this.scriptExecutor.executeAction(this.agentAppPath, cardNumber);
  }

  private handleImageSelected(imageUri: string): void {
    this.scriptExecutor.executeTake(this.agentAppPath, imageUri);
  }

  private openPhotoPicker(): void {
    try {
      const photoSelectOptions: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      photoViewPicker.select(photoSelectOptions).then((result: picker.PhotoSelectResult) => {
        if (result.photoUris.length > 0) {
          this.previewImageUri = result.photoUris[0];
          this.handleImageSelected(this.previewImageUri);
        }
      }).catch((err: Error) => {
        logger.error(TAG, `Photo picker error: ${err.message}`);
      });
    } catch (err) {
      logger.error(TAG, `Failed to open photo picker`);
    }
  }

  private openCamera(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.imageCapture',
      };
      context.startAbility(want).catch((err: Error) => {
        logger.error(TAG, `Camera error: ${err.message}`);
      });
    } catch (err) {
      logger.error(TAG, `Failed to open camera`);
    }
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('sys.color.titlebar_icon_color')])
          .onClick(() => {
            this.getUIContext().getRouter().back();
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
            this.refreshCards();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Tabs({ index: this.currentTab }) {
        TabContent() {
          this.CardListTab()
        }
        .tabBar('卡片列表')

        TabContent() {
          this.ImageImportTab()
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

  @Builder
  CardListTab() {
    if (this.cardList.length === 0) {
      Column() {
        Text('暂无卡片数据')
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
            Column() {
              Text(card.title)
                .fontSize(commonConstants.TITLE_FONT_SIZE)
                .fontWeight(commonConstants.TITLE_FONT_WEIGHT)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .width('100%')
                .margin({ bottom: 8 })

              Text(card.line0)
                .fontSize(commonConstants.LINE_FONT_SIZE)
                .fontWeight(commonConstants.LINE_FONT_WEIGHT)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .width('100%')
                .margin({ bottom: 4 })

              if (card.line1.length > 0) {
                Text(card.line1)
                  .fontSize(commonConstants.LINE_FONT_SIZE)
                  .fontWeight(commonConstants.LINE_FONT_WEIGHT)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .width('100%')
                  .margin({ bottom: 8 })
              }

              if (card.buttonText.length > 0) {
                Row() {
                  Button(card.buttonText)
                    .fontSize(14)
                    .fontColor(Color.White)
                    .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
                    .borderRadius(8)
                    .height(36)
                    .onClick(() => {
                      this.handleActionClick(card.number);
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
          .margin({ bottom: commonConstants.CARD_GAP })
        }, (card: CardData) => card.number.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  ImageImportTab() {
    Column() {
      if (this.previewImageUri.length > 0) {
        Image(this.previewImageUri)
          .width('80%')
          .height(200)
          .objectFit(ImageFit.Contain)
          .borderRadius(12)
          .margin({ bottom: 16 })
      } else {
        Column() {
          Text('选择或拍摄图片')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('80%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(12)
        .backgroundColor($r('sys.color.ohos_id_color_component_normal'))
        .margin({ bottom: 16 })
      }

      Row() {
        Button('拍照')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .margin({ right: 12 })
          .onClick(() => {
            this.openCamera();
          })

        Button('从相册选择')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.openPhotoPicker();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}