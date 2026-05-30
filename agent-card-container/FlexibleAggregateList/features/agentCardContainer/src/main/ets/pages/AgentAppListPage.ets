import { AgentAppListComponent } from '../view/AgentAppListComponent';
import { AgentAppEntry } from '../model/AgentAppEntry';
import { AgentAppListViewModel } from '../viewmodel/AgentAppListViewModel';

@Entry
@Component
struct AgentAppListPage {
  @State agentAppList: AgentAppEntry[] = [];

  aboutToAppear(): void {
    this.refreshList();
  }

  onPageShow(): void {
    this.refreshList();
  }

  private refreshList(): void {
    const viewModel = new AgentAppListViewModel();
    this.agentAppList = viewModel.getAgentAppList();
  }

  build() {
    Column() {
      AgentAppListComponent({
        agentAppList: this.agentAppList,
        onItemClick: (entry: AgentAppEntry) => {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/AgentAppDetailPage',
            params: { dirName: entry.dirName, fullPath: entry.fullPath, appName: entry.appName }
          });
        },
        onRefresh: () => {
          this.refreshList();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

export { AgentAppListPage };