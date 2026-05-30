import { fileIo as fs } from '@kit.CoreFileKit';
import { webview } from '@kit.ArkWeb';
import { Logger } from '@ohos/common';

const logger = new Logger();
const TAG = 'ScriptExecutor';

export class ScriptExecutor {
  private webController: webview.WebviewController | null = null;

  setWebController(controller: webview.WebviewController): void {
    this.webController = controller;
  }

  executeAction(agentAppPath: string, cardNumber: number): void {
    const scriptPath: string = `${agentAppPath}/action.js`;
    const paramStr: string = `${cardNumber}`;
    this.executeScript(scriptPath, 'action', paramStr);
  }

  executeTake(agentAppPath: string, imageUri: string): void {
    const scriptPath: string = `${agentAppPath}/take.js`;
    const paramStr: string = `'${imageUri}'`;
    this.executeScript(scriptPath, 'take', paramStr);
  }

  private executeScript(scriptPath: string, functionName: string, paramStr: string): void {
    try {
      if (!fs.accessSync(scriptPath)) {
        logger.warn(TAG, `Script not found: ${scriptPath}`);
        return;
      }
      const scriptContent: string = fs.readTextSync(scriptPath);
      if (this.webController !== null) {
        const callExpr: string = `${scriptContent}; ${functionName}(${paramStr})`;
        this.webController.runJavaScript(callExpr);
      } else {
        logger.warn(TAG, 'WebviewController not initialized');
      }
    } catch (err) {
      logger.error(TAG, `Failed to execute script ${functionName}`);
    }
  }
}
