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
      const rootPath: string = commonConstants.AGENT_CARDS_ROOT;
      if (!fs.accessSync(rootPath)) {
        logger.info(TAG, `Root directory does not exist: ${rootPath}`);
        return entries;
      }
      const dirList: string[] = fs.listFileSync(rootPath);
      for (const dirName of dirList) {
        const match: RegExpMatchArray | null = dirName.match(/^(\d+)\.(.+)$/);
        if (match !== null) {
          const number: number = parseInt(match[1], 10);
          const appName: string = match[2];
          const fullPath: string = `${rootPath}/${dirName}`;
          entries.push(new AgentAppEntry(number, appName, dirName, fullPath));
        }
      }
      entries.sort((a: AgentAppEntry, b: AgentAppEntry) => a.number - b.number);
    } catch (err) {
      logger.error(TAG, `Failed to scan AgentApp dirs`);
    }
    return entries;
  }

  static scanCardJsonFiles(agentAppPath: string): string[] {
    const jsonFiles: string[] = [];
    try {
      const listPath: string = `${agentAppPath}/${commonConstants.LIST_DIR_NAME}`;
      if (!fs.accessSync(listPath)) {
        logger.info(TAG, `List directory does not exist: ${listPath}`);
        return jsonFiles;
      }
      const fileList: string[] = fs.listFileSync(listPath);
      for (const fileName of fileList) {
        if (fileName.endsWith('.json')) {
          jsonFiles.push(`${listPath}/${fileName}`);
        }
      }
    } catch (err) {
      logger.error(TAG, `Failed to scan card JSON files`);
    }
    return jsonFiles;
  }
}