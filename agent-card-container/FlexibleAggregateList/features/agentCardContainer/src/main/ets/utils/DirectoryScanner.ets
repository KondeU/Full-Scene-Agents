import { fileIo as fs } from '@kit.CoreFileKit';
import { Logger } from '@ohos/common';
import { AgentAppEntry } from '../model/AgentAppEntry';
import { commonConstants } from '../constants/CommonConstants';

const logger = new Logger();
const TAG = 'DirectoryScanner';

export class DirectoryScanner {
  static scanAgentAppDirs(): AgentAppEntry[] {
    const entries: AgentAppEntry[] = [];
    try {
      const rootPath = commonConstants.AGENT_CARDS_ROOT;
      if (!fs.accessSync(rootPath)) {
        logger.info(TAG, `Root directory does not exist: ${rootPath}`);
        return entries;
      }
      const dirList = fs.listFileSync(rootPath);
      for (const dirName of dirList) {
        const match = dirName.match(/^(\d+)\.(.+)$/);
        if (match) {
          const number = parseInt(match[1], 10);
          const appName = match[2];
          const fullPath = `${rootPath}/${dirName}`;
          entries.push(new AgentAppEntry(number, appName, dirName, fullPath));
        }
      }
      entries.sort((a, b) => a.number - b.number);
    } catch (err) {
      logger.error(TAG, `Failed to scan AgentApp dirs: ${JSON.stringify(err)}`);
    }
    return entries;
  }

  static scanCardJsonFiles(agentAppPath: string): string[] {
    const jsonFiles: string[] = [];
    try {
      const listPath = `${agentAppPath}/${commonConstants.LIST_DIR_NAME}`;
      if (!fs.accessSync(listPath)) {
        logger.info(TAG, `List directory does not exist: ${listPath}`);
        return jsonFiles;
      }
      const fileList = fs.listFileSync(listPath);
      for (const fileName of fileList) {
        if (fileName.endsWith('.json')) {
          jsonFiles.push(`${listPath}/${fileName}`);
        }
      }
    } catch (err) {
      logger.error(TAG, `Failed to scan card JSON files: ${JSON.stringify(err)}`);
    }
    return jsonFiles;
  }
}