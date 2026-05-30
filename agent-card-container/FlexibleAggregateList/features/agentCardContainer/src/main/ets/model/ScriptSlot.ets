export class ScriptSlot {
  name: string = '';
  scriptPath: string = '';
  functionName: string = '';

  constructor(name: string, scriptPath: string, functionName: string) {
    this.name = name;
    this.scriptPath = scriptPath;
    this.functionName = functionName;
  }

  static ACTION_SLOT(dirPath: string): ScriptSlot {
    return new ScriptSlot('action', `${dirPath}/action.js`, 'action');
  }

  static TAKE_SLOT(dirPath: string): ScriptSlot {
    return new ScriptSlot('take', `${dirPath}/take.js`, 'take');
  }
}