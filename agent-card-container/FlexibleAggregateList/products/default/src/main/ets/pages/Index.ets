import { AgentAppEntry } from '../model/AgentAppEntry';
import { AgentAppListViewModel } from '../viewmodel/AgentAppListViewModel';
import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';

const PREF_NAME = 'agent_cards_config';
const PREF_KEY_ROOT = 'root_path';

@Entry
@Component
struct Index {
  @State agentAppList: AgentAppEntry[] = [];
  @State needsPickDir: boolean = false;
  private viewModel: AgentAppListViewModel = new AgentAppListViewModel();
  private rootPath: string = '';

  aboutToAppear(): void {
    this.initRootPath();
  }

  onPageShow(): void {
    if (this.rootPath.length > 0) {
      this.refreshList();
    }
  }

  private initRootPath(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      preferences.getPreferences(context, PREF_NAME).then((prefs: preferences.Preferences) => {
        const saved: preferences.ValueType = prefs.getSync(PREF_KEY_ROOT, '');
        if (typeof saved === 'string' && saved.length > 0 && fs.accessSync(saved)) {
          this.rootPath = saved;
          console.info('Index', `Loaded saved root: ${this.rootPath}`);
          this.refreshList();
          return;
        }
        this.needsPickDir = true;
      }).catch(() => {
        this.needsPickDir = true;
      });
    } catch (e) {
      this.needsPickDir = true;
    }
  }

  private openFilePicker(): void {
    try {
      const documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      const documentViewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      documentViewPicker.select(documentSelectOptions).then((uris: string[]) => {
        if (uris.length > 0) {
          this.onDirPicked(uris[0]);
        }
      }).catch((err: Error) => {
        console.error('Index', `Picker cancelled or failed: ${err.message}`);
      });
    } catch (e) {
      console.error('Index', `Failed to open picker: ${JSON.stringify(e)}`);
    }
  }

  private onDirPicked(uri: string): void {
    try {
      // Derive root path from the picked file URI
      // URI format: file://docs/storage/Users/currentUser/Download/AgentCards/...
      // First try: walk up from the file path to find AgentCards dir
      let filePath: string = uri;
      if (uri.startsWith('file://')) {
        filePath = decodeURIComponent(uri.substring('file://docs'.length));
      }

      // Find the AgentCards segment and use everything before it as root
      const agentCardsIdx: number = filePath.indexOf('/AgentCards/');
      if (agentCardsIdx >= 0) {
        this.rootPath = filePath.substring(0, agentCardsIdx + '/AgentCards'.length);
      } else {
        // Fallback: use parent of the picked file's parent (the app dir)
        const lastSlash: number = filePath.lastIndexOf('/');
        const secondLastSlash: number = filePath.lastIndexOf('/', lastSlash - 1);
        this.rootPath = filePath.substring(0, secondLastSlash);
      }
      // Normalize path
      if (!this.rootPath.startsWith('/')) {
        this.rootPath = '/' + this.rootPath;
      }

      console.info('Index', `Picked root: ${this.rootPath}`);

      // Save to preferences
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      preferences.getPreferences(context, PREF_NAME).then((prefs: preferences.Preferences) => {
        prefs.putSync(PREF_KEY_ROOT, this.rootPath);
        prefs.flush();
      });

      this.needsPickDir = false;
      this.refreshList();
    } catch (e) {
      console.error('Index', `Failed to process picked dir: ${JSON.stringify(e)}`);
    }
  }

  private refreshList(): void {
    try {
      this.agentAppList = this.viewModel.getAgentAppList(this.rootPath);
    } catch (err) {
      console.error('Index', `refreshList failed: ${JSON.stringify(err)}`);
    }
  }

  build() {
    Column() {
      Row() {
        Text('AgentCards')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Row() {
          SymbolGlyph($r('sys.symbol.folder'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
            .margin({ right: 12 })
            .onClick(() => {
              this.openFilePicker();
            })
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
            .onClick(() => {
              this.refreshList();
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.needsPickDir) {
        Column() {
          SymbolGlyph($r('sys.symbol.folder'))
            .fontSize(48)
            .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
            .margin({ bottom: 16 })
          Text('请选择AgentCards目录')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ bottom: 8 })
          Text('点击下方按钮，导航到Download/AgentCards目录，选择任意文件即可')
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .margin({ bottom: 24 })
          Button('选择目录')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
            .borderRadius(8)
            .height(40)
            .onClick(() => {
              this.openFilePicker();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.agentAppList.length === 0) {
        Column() {
          Text('暂无AgentApp')
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
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/AgentAppDetailPage',
                  params: { dirName: entry.dirName, fullPath: entry.fullPath, appName: entry.appName }
                });
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
