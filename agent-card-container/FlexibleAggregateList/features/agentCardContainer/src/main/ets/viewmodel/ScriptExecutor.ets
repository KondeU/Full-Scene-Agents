import { fileIo as fs } from '@kit.CoreFileKit';
import { webview } from '@kit.ArkWeb';
import { Logger } from '@ohos/common';
import { ScriptSlot } from '../model/ScriptSlot';

const logger = new Logger();
const TAG = 'ScriptExecutor';

export class ScriptExecutor {
  private webView: webview.Webview | null = null;

  setWebView(webView: webview.Webview): void {
    this.webView = webView;
  }

  executeAction(agentAppPath: string, cardNumber: number): void {
    const slot = ScriptSlot.ACTION_SLOT(agentAppPath);
    this.executeScript(slot, `${cardNumber}`);
  }

  executeTake(agentAppPath: string, imageUri: string): void {
    const slot = ScriptSlot.TAKE_SLOT(agentAppPath);
    this.executeScript(slot, `'${imageUri}'`);
  }

  private executeScript(slot: ScriptSlot, paramStr: string): void {
    try {
      if (!fs.accessSync(slot.scriptPath)) {
        logger.warn(TAG, `Script not found: ${slot.scriptPath}`);
        return;
      }
      const scriptContent = fs.readTextSync(slot.scriptPath);
      if (this.webView) {
        const callExpr = `${scriptContent}; ${slot.functionName}(${paramStr})`;
        this.webView.controller.runJavaScript(callExpr);
      } else {
        logger.warn(TAG, 'WebView not initialized, cannot execute script');
      }
    } catch (err) {
      logger.error(TAG, `Failed to execute script ${slot.name}: ${JSON.stringify(err)}`);
    }
  }
}

const scriptExecutor = new ScriptExecutor();
export default scriptExecutor;