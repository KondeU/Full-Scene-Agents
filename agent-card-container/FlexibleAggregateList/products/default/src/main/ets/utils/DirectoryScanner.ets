import { fileIo as fs } from '@kit.CoreFileKit';
import { AgentAppEntry } from '../model/AgentAppEntry';

const TAG = 'DirectoryScanner';

export class DirectoryScanner {
  static scanAgentAppDirs(rootPath: string): AgentAppEntry[] {
    const entries: AgentAppEntry[] = [];
    try {
      console.info(TAG, `Scanning root: ${rootPath}`);
      if (!fs.accessSync(rootPath)) {
        console.info(TAG, `Root directory does not exist: ${rootPath}`);
        return entries;
      }
      const dirList: string[] = fs.listFileSync(rootPath);
      console.info(TAG, `Found ${dirList.length} entries`);
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
      console.error(TAG, `Failed to scan AgentApp dirs: ${JSON.stringify(err)}`);
    }
    return entries;
  }

  static scanCardJsonFiles(agentAppPath: string): string[] {
    const jsonFiles: string[] = [];
    try {
      const listPath: string = `${agentAppPath}/list`;
      if (!fs.accessSync(listPath)) {
        console.info(TAG, `List directory does not exist: ${listPath}`);
        return jsonFiles;
      }
      const fileList: string[] = fs.listFileSync(listPath);
      for (const fileName of fileList) {
        if (fileName.endsWith('.json')) {
          jsonFiles.push(`${listPath}/${fileName}`);
        }
      }
    } catch (err) {
      console.error(TAG, `Failed to scan card JSON files: ${JSON.stringify(err)}`);
    }
    return jsonFiles;
  }
}
