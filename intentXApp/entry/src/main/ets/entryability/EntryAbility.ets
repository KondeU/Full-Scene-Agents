import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { securePrefs } from '../common/SecurePrefs';
import { mainViewModel } from '../viewmodel/MainViewModel';

const DOMAIN = 0x0001;
const TAG = 'EntryAbility';

/**
 * Main Entry Ability for OpenClaw HarmonyOS
 */
export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | null = null;

  /**
   * Called when the ability is created
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');

    // Make UIAbilityContext available globally for resource lookups in non-UI classes
    AppStorage.setOrCreate<Context>('abilityContext', this.context);
    AppStorage.setOrCreate<number>('localeVersion', 0);
    AppStorage.setOrCreate<boolean>('isForeground', false);

    // 从卡片点击或其他路由参数中提取目标 Tab
    this.applyTargetTab(want);

    // Initialize secure preferences
    securePrefs.init(this.context)
      .then(() => {
        hilog.info(DOMAIN, TAG, 'SecurePrefs initialized');
      })
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Failed to initialize SecurePrefs: %{public}s', error.message);
      });
  }

  /**
   * Called when the ability is destroyed
   */
  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
    this.windowStage = null;
  }

  /**
   * Called when the ability window is created
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');

    this.windowStage = windowStage;

    // Load the main page
    windowStage.loadContent('pages/Index', (err) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });

    // Set window properties
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowBackgroundColor('#FFFFFF');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window: %{public}s', err.message);
    });
  }

  /**
   * Called when the ability window is destroyed
   */
  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  /**
   * Called when the ability moves to foreground
   */
  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
    AppStorage.setOrCreate<boolean>('isForeground', true);
    this.bumpLocaleVersion();
    mainViewModel.refreshLocalizedUiState();
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
    AppStorage.setOrCreate<boolean>('isForeground', false);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onNewWant');
    this.applyTargetTab(want);
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'onFormEvent, formId=' + formId + ', message=' + message);
  }

  private applyTargetTab(want: Want): void {
    // postCardAction 的 params 嵌套在 want.parameters.params 中，是 JSON 字符串
    const rawParams = want.parameters?.['params'];
    if (typeof rawParams !== 'string' || rawParams.trim().length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(rawParams) as Record<string, string>;
      const targetPage = (parsed['targetPage'] || '').trim();
      const importAction = (parsed['importAction'] || '').trim();
      if (targetPage.length > 0) {
        const tabIndex = this.mapTargetPageToTab(targetPage);
        if (tabIndex >= 0) {
          AppStorage.setOrCreate<number>('pendingActiveTab', tabIndex);
          hilog.info(DOMAIN, TAG, 'applyTargetTab: ' + targetPage + ' → tab ' + tabIndex);
        }
      }
      if (importAction.length > 0) {
        AppStorage.setOrCreate<string>('pendingImportAction', importAction);
        hilog.info(DOMAIN, TAG, 'applyTargetTab: importAction=' + importAction);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'applyTargetTab: failed to parse params');
    }
  }

  private mapTargetPageToTab(target: string): number {
    switch (target) {
      case 'connect':  return 0;
      case 'chat':     return 1;
      case 'voice':    return 2;
      case 'screen':   return 3;
      case 'settings': return 4;
      case 'import':   return 5;
      case 'debug':    return 6;
      default:         return -1;
    }
  }

  private bumpLocaleVersion(): void {
    const current = AppStorage.get<number>('localeVersion') ?? 0;
    AppStorage.setOrCreate<number>('localeVersion', current + 1);
  }
}
