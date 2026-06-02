import { DirectoryScanner } from '../utils/DirectoryScanner';
import { AgentAppEntry } from '../model/AgentAppEntry';

export class AgentAppListViewModel {
  getAgentAppList(rootPath: string): AgentAppEntry[] {
    return DirectoryScanner.scanAgentAppDirs(rootPath);
  }
}
