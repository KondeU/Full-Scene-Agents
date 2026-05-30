export class AgentAppEntry {
  number: number = 0;
  appName: string = '';
  dirName: string = '';
  fullPath: string = '';

  constructor(number: number, appName: string, dirName: string, fullPath: string) {
    this.number = number;
    this.appName = appName;
    this.dirName = dirName;
    this.fullPath = fullPath;
  }
}