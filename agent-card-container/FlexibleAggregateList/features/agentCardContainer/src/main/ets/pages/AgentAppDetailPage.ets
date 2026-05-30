import { CardData } from '../model/CardData';
import { AgentAppDetailView } from '../view/AgentAppDetailView';
import { CardListViewModel } from '../viewmodel/CardListViewModel';
import scriptExecutor from '../viewmodel/ScriptExecutor';
import { commonConstants } from '../constants/CommonConstants';

interface DetailPageParams {
  dirName: string;
  fullPath: string;
  appName: string;
}

@Entry
@Component
struct AgentAppDetailPage {
  @State cardList: CardData[] = [];
  @State agentAppName: string = '';
  @State agentAppPath: string = '';
  private viewModel: CardListViewModel = new CardListViewModel();

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as DetailPageParams;
    if (params) {
      this.agentAppName = params.appName;
      this.agentAppPath = params.fullPath;
    }
    this.refreshCards();
  }

  onPageShow(): void {
    this.refreshCards();
  }

  private refreshCards(): void {
    this.cardList = this.viewModel.getCardList(this.agentAppPath);
  }

  build() {
    Column() {
      AgentAppDetailView({
        cardList: this.cardList,
        agentAppName: this.agentAppName,
        agentAppPath: this.agentAppPath,
        onRefresh: () => {
          this.refreshCards();
        },
        onBack: () => {
          this.getUIContext().getRouter().back();
        },
        onActionClick: (cardNumber: number) => {
          scriptExecutor.executeAction(this.agentAppPath, cardNumber);
        },
        onImageSelected: (imageUri: string) => {
          scriptExecutor.executeTake(this.agentAppPath, imageUri);
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

export { AgentAppDetailPage };