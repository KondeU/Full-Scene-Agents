import { DirectoryScanner } from '../utils/DirectoryScanner';
import { AgentAppEntry } from '../model/AgentAppEntry';

export class AgentAppListViewModel {
  getAgentAppList(): AgentAppEntry[] {
    return DirectoryScanner.scanAgentAppDirs();
  }
}