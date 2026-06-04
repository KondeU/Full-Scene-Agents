import { AgentAppEntry } from '../model/AgentAppEntry';
import { AgentAppListViewModel } from '../viewmodel/AgentAppListViewModel';
import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs, fileShare } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const PREF_NAME = 'agent_cards_config';
const PREF_KEY_ROOT = 'root_uri';

@Entry
@Component
struct Index {
  @State agentAppList: AgentAppEntry[] = [];
  @State needsPickDir: boolean = false;
  private viewModel: AgentAppListViewModel = new AgentAppListViewModel();
  private rootDirUri: string = '';

  aboutToAppear(): void {
    this.initRootPath();
  }

  onPageShow(): void {
    if (this.rootDirUri.length > 0) {
      this.refreshList();
    }
  }

  private initRootPath(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      preferences.getPreferences(context, PREF_NAME).then((prefs: preferences.Preferences) => {
        const savedUri: preferences.ValueType = prefs.getSync(PREF_KEY_ROOT, '');
        if (typeof savedUri === 'string' && savedUri.length > 0) {
          this.activateAndUse(savedUri, prefs);
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

  private activateAndUse(uri: string, prefs: preferences.Preferences): void {
    const policyInfo: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE,
    };
    fileShare.checkPersistentPermission([policyInfo]).then((results: Array<boolean>) => {
      if (results.length > 0 && results[0]) {
        // Has persisted permission, activate it
        fileShare.activatePermission([policyInfo]).then(() => {
          console.info('Index', 'Activated persisted URI');
          this.rootDirUri = uri;
          this.refreshList();
        }).catch((err: BusinessError) => {
          console.error('Index', `Activate failed: ${err.message}`);
          this.needsPickDir = true;
        });
      } else {
        // No persisted permission, need to pick again
        console.info('Index', 'No persistent permission, need re-pick');
        this.needsPickDir = true;
      }
    }).catch(() => {
      this.needsPickDir = true;
    });
  }

  private openFolderPicker(): void {
    try {
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = ['_picker_placeholder_'];
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      documentPicker.save(saveOptions).then((uris: string[]) => {
        if (uris.length > 0) {
          this.onFolderPicked(uris[0]);
        }
      }).catch((err: BusinessError) => {
        console.error('Index', `Picker cancelled: ${err.message}`);
      });
    } catch (e) {
      console.error('Index', `Failed to open picker: ${JSON.stringify(e)}`);
    }
  }

  private onFolderPicked(saveUri: string): void {
    try {
      console.info('Index', `Save URI: ${saveUri}`);

      // save() returns: file://docs/.../AgentCards/_picker_placeholder_
      // Strip the placeholder filename to get the directory URI
      const lastSlash: number = saveUri.lastIndexOf('/');
      this.rootDirUri = saveUri.substring(0, lastSlash);
      console.info('Index', `Derived folder URI: ${this.rootDirUri}`);

      // Persist the directory URI permission
      const policyInfo: fileShare.PolicyInfo = {
        uri: this.rootDirUri,
        operationMode: fileShare.OperationMode.READ_MODE,
      };
      fileShare.persistPermission([policyInfo]).then(() => {
        console.info('Index', 'Persisted folder URI');
      }).catch((err: BusinessError) => {
        console.info('Index', `Persist failed: ${err.message}`);
      });

      // Save URI to preferences
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      preferences.getPreferences(context, PREF_NAME).then((prefs: preferences.Preferences) => {
        prefs.putSync(PREF_KEY_ROOT, this.rootDirUri);
        prefs.flush();
      });

      // Diagnostic: verify folder access
      this.runDiagnostics();

      this.needsPickDir = false;
      this.refreshList();
    } catch (e) {
      console.error('Index', `Failed to process picked folder: ${JSON.stringify(e)}`);
    }
  }

  private runDiagnostics(): void {
    console.info('DIAG', `=== Folder Access Diagnostic ===`);
    console.info('DIAG', `rootDirUri: ${this.rootDirUri}`);
    try {
      // 1) accessSync on the folder URI itself
      const ok: boolean = fs.accessSync(this.rootDirUri);
      console.info('DIAG', `accessSync(rootDirUri) = ${ok}`);
    } catch (e) {
      console.error('DIAG', `accessSync(rootDirUri) failed: ${JSON.stringify(e)}`);
    }
    try {
      // 2) list file names directly under AgentCards
      const list: string[] = fs.listFileSync(this.rootDirUri);
      console.info('DIAG', `listFileSync(rootDirUri) => ${list.length} items`);
      list.forEach((name: string, i: number) => {
        console.info('DIAG', `  [${i}] ${name}`);
      });
    } catch (e) {
      console.error('DIAG', `listFileSync(rootDirUri) failed: ${JSON.stringify(e)}`);
    }
    // 3) try to list sub-directories and their list/ contents
    try {
      const topList: string[] = fs.listFileSync(this.rootDirUri);
      for (const child of topList) {
        const childFull: string = `${this.rootDirUri}/${child}`;
        try {
          if (fs.accessSync(childFull)) {
            const inner: string[] = fs.listFileSync(childFull);
            console.info('DIAG', `  ${child}/ => ${inner.length} items`);
            // check for list/ subdir
            const listDir: string = `${childFull}/list`;
            if (fs.accessSync(listDir)) {
              const jsonFiles: string[] = fs.listFileSync(listDir);
              console.info('DIAG', `  ${child}/list/ => ${jsonFiles.length} items`);
              jsonFiles.forEach((j: string) => console.info('DIAG', `    ${j}`));
            }
          }
        } catch (err) {
          console.info('DIAG', `  ${child}/ => cannot access: ${JSON.stringify(err)}`);
        }
      }
    } catch (e) {
      console.error('DIAG', `Recursive scan failed: ${JSON.stringify(e)}`);
    }
    console.info('DIAG', `=== Diagnostic End ===`);
  }

  private refreshList(): void {
    try {
      // Use the folder URI directly with fileIo
      this.agentAppList = this.viewModel.getAgentAppList(this.rootDirUri);
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
              this.openFolderPicker();
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
          Text('请导航到Download/AgentCards目录并点击保存')
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
              this.openFolderPicker();
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
