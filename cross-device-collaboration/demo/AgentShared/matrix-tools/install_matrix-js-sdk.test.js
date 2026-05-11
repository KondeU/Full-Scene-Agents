/**
 * install_matrix-js-sdk.test.js
 * 
 * Test suite for install_matrix-js-sdk.js - Dependency installation
 * Coverage target: >80% branches, functions, lines, statements
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

jest.mock('child_process');
jest.mock('fs');

const { parseArgs, detectPackageManager, checkInstalled, getInstalledVersion, buildInstallCommand, installMatrixJsSdk } = require('./install_matrix-js-sdk');

describe('install_matrix-js-sdk.js', () => {
  let mockConsole;

  beforeEach(() => {
    mockConsole = global.mockConsole();
    execSync.mockReset();
    fs.existsSync.mockReset();
    fs.readFileSync.mockReset();
    fs.existsSync.mockReturnValue(false);
    fs.readFileSync.mockReturnValue('');
    execSync.mockImplementation(() => { throw new Error('command not found'); });
  });

  afterEach(() => {
    mockConsole.restore();
    jest.clearAllMocks();
  });

  describe('parseArgs', () => {
    test('should parse --version option', () => {
      const argv = ['node', 'script', '--version', '32.0.0'];
      const result = parseArgs(argv);
      expect(result.version).toBe('32.0.0');
    });

    test('should parse -v short option for version', () => {
      const argv = ['node', 'script', '-v', 'latest'];
      const result = parseArgs(argv);
      expect(result.version).toBe('latest');
    });

    test('should parse --package-manager npm', () => {
      const argv = ['node', 'script', '--package-manager', 'npm'];
      const result = parseArgs(argv);
      expect(result.packageManager).toBe('npm');
    });

    test('should parse --package-manager yarn', () => {
      const argv = ['node', 'script', '--package-manager', 'yarn'];
      const result = parseArgs(argv);
      expect(result.packageManager).toBe('yarn');
    });

    test('should parse --package-manager pnpm', () => {
      const argv = ['node', 'script', '--package-manager', 'pnpm'];
      const result = parseArgs(argv);
      expect(result.packageManager).toBe('pnpm');
    });

    test('should exit 1 for invalid package manager', () => {
      const argv = ['node', 'script', '--package-manager', 'invalid'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: 包管理器必须是 npm, yarn 或 pnpm']);
    });

    test('should parse -p short option for package manager', () => {
      const argv = ['node', 'script', '-p', 'pnpm'];
      const result = parseArgs(argv);
      expect(result.packageManager).toBe('pnpm');
    });

    test('should parse --global flag', () => {
      const argv = ['node', 'script', '--global'];
      const result = parseArgs(argv);
      expect(result.global).toBe(true);
    });

    test('should parse -g short option for global', () => {
      const argv = ['node', 'script', '-g'];
      const result = parseArgs(argv);
      expect(result.global).toBe(true);
    });

    test('should parse --save-dev flag', () => {
      const argv = ['node', 'script', '--save-dev'];
      const result = parseArgs(argv);
      expect(result.saveDev).toBe(true);
    });

    test('should parse -D short option for save-dev', () => {
      const argv = ['node', 'script', '-D'];
      const result = parseArgs(argv);
      expect(result.saveDev).toBe(true);
    });

    test('should parse --check-only flag', () => {
      const argv = ['node', 'script', '--check-only'];
      const result = parseArgs(argv);
      expect(result.checkOnly).toBe(true);
    });

    test('should parse -c short option for check-only', () => {
      const argv = ['node', 'script', '-c'];
      const result = parseArgs(argv);
      expect(result.checkOnly).toBe(true);
    });

    test('should show help with --help', () => {
      const argv = ['node', 'script', '--help'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 0');
    });

    test('should show help with -h', () => {
      const argv = ['node', 'script', '-h'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 0');
    });

    test('should exit 1 for unknown argument', () => {
      const argv = ['node', 'script', '--unknown'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
    });

    test('should exit 1 when --version is last argument without value', () => {
      const argv = ['node', 'script', '--version'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: --version 参数需要一个值']);
    });

    test('should exit 1 when --package-manager is last argument without value', () => {
      const argv = ['node', 'script', '--package-manager'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: --package-manager 参数需要一个值']);
    });

    test('should have default values', () => {
      const argv = ['node', 'script'];
      const result = parseArgs(argv);
      expect(result.version).toBeNull();
      expect(result.packageManager).toBeNull();
      expect(result.global).toBe(false);
      expect(result.saveDev).toBe(false);
      expect(result.checkOnly).toBe(false);
    });

    test('should parse multiple options', () => {
      const argv = ['node', 'script', '-v', '32.0.0', '-p', 'pnpm', '-g', '-D'];
      const result = parseArgs(argv);
      expect(result.version).toBe('32.0.0');
      expect(result.packageManager).toBe('pnpm');
      expect(result.global).toBe(true);
      expect(result.saveDev).toBe(true);
    });
  });

  describe('detectPackageManager', () => {
    test('should return pnpm when pnpm-lock.yaml exists', () => {
      fs.existsSync.mockImplementation((p) => String(p).endsWith('pnpm-lock.yaml'));
      expect(detectPackageManager()).toBe('pnpm');
    });

    test('should return yarn when yarn.lock exists', () => {
      fs.existsSync.mockImplementation((p) => {
        if (String(p).endsWith('pnpm-lock.yaml')) return false;
        if (String(p).endsWith('yarn.lock')) return true;
        return false;
      });
      expect(detectPackageManager()).toBe('yarn');
    });

    test('should return npm when package-lock.json exists', () => {
      fs.existsSync.mockImplementation((p) => {
        if (String(p).endsWith('pnpm-lock.yaml')) return false;
        if (String(p).endsWith('yarn.lock')) return false;
        if (String(p).endsWith('package-lock.json')) return true;
        return false;
      });
      expect(detectPackageManager()).toBe('npm');
    });

    test('should detect pnpm via command when no lock files', () => {
      fs.existsSync.mockReturnValue(false);
      execSync.mockImplementation((cmd) => {
        if (cmd.includes('pnpm --version')) return '8.0.0';
        throw new Error('not found');
      });
      expect(detectPackageManager()).toBe('pnpm');
    });

    test('should detect yarn via command when pnpm not found', () => {
      fs.existsSync.mockReturnValue(false);
      execSync.mockImplementation((cmd) => {
        if (cmd.includes('pnpm --version')) throw new Error('not found');
        if (cmd.includes('yarn --version')) return '1.22.0';
        throw new Error('not found');
      });
      expect(detectPackageManager()).toBe('yarn');
    });

    test('should detect npm via command when others not found', () => {
      execSync.mockImplementation((cmd) => {
        if (cmd === 'npm --version') return '10.0.0';
        throw new Error('not found');
      });
      expect(detectPackageManager()).toBe('npm');
    });

    test('should return null when no package manager available', () => {
      fs.existsSync.mockReturnValue(false);
      execSync.mockImplementation(() => { throw new Error('not found'); });
      expect(detectPackageManager()).toBeNull();
    });
  });

  describe('checkInstalled', () => {
    let resolveSpy;
    
    beforeEach(() => {
      execSync.mockReset();
      resolveSpy = jest.spyOn(require, 'resolve');
    });
    
    afterEach(() => {
      resolveSpy.mockRestore();
    });

    test('should return true when local package is installed', () => {
      resolveSpy.mockReturnValue('/node_modules/matrix-js-sdk');
      expect(checkInstalled(false)).toBe(true);
    });

    test('should return true when global package is installed', () => {
      execSync.mockReturnValue('/usr/lib/node_modules');
      resolveSpy.mockReturnValue('/usr/lib/node_modules/matrix-js-sdk');
      expect(checkInstalled(true)).toBe(true);
    });

    test('should return false when package not installed', () => {
      resolveSpy.mockImplementation(() => { throw new Error('Cannot find module'); });
      expect(checkInstalled(false)).toBe(false);
    });
  });

  describe('getInstalledVersion', () => {
    let resolveSpy;
    
    beforeEach(() => {
      execSync.mockReset();
      resolveSpy = jest.spyOn(require, 'resolve');
    });
    
    afterEach(() => {
      resolveSpy.mockRestore();
    });

    test('should return version when package is installed locally', () => {
      resolveSpy.mockReturnValue('/node_modules/matrix-js-sdk/package.json');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '32.0.0' }));
      expect(getInstalledVersion(false)).toBe('32.0.0');
    });

    test('should return version when package is installed globally', () => {
      execSync.mockReturnValue('/usr/lib/node_modules');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '31.0.0' }));
      expect(getInstalledVersion(true)).toBe('31.0.0');
    });

    test('should return null when package not installed', () => {
      resolveSpy.mockImplementation(() => { throw new Error('Cannot find module'); });
      expect(getInstalledVersion(false)).toBeNull();
    });

    test('should return null when package.json read fails', () => {
      resolveSpy.mockReturnValue('/node_modules/matrix-js-sdk/package.json');
      fs.readFileSync.mockImplementation(() => { throw new Error('Read error'); });
      expect(getInstalledVersion(false)).toBeNull();
    });
  });

  describe('buildInstallCommand', () => {
    test('should build npm install command', () => {
      expect(buildInstallCommand('npm', null, false, false)).toEqual(['npm', 'install', 'matrix-js-sdk']);
    });

    test('should build npm install command with version', () => {
      expect(buildInstallCommand('npm', '32.0.0', false, false)).toEqual(['npm', 'install', 'matrix-js-sdk@32.0.0']);
    });

    test('should build npm install command with global flag', () => {
      expect(buildInstallCommand('npm', null, true, false)).toEqual(['npm', 'install', '-g', 'matrix-js-sdk']);
    });

    test('should build npm install command with save-dev flag', () => {
      expect(buildInstallCommand('npm', null, false, true)).toEqual(['npm', 'install', '--save-dev', 'matrix-js-sdk']);
    });

    test('should build yarn add command', () => {
      expect(buildInstallCommand('yarn', null, false, false)).toEqual(['yarn', 'add', 'matrix-js-sdk']);
    });

    test('should build yarn global add command', () => {
      expect(buildInstallCommand('yarn', null, true, false)).toEqual(['yarn', 'global', 'add', 'matrix-js-sdk']);
    });

    test('should build yarn add command with dev flag', () => {
      expect(buildInstallCommand('yarn', '32.0.0', false, true)).toEqual(['yarn', 'add', '--dev', 'matrix-js-sdk@32.0.0']);
    });

    test('should build pnpm add command', () => {
      expect(buildInstallCommand('pnpm', null, false, false)).toEqual(['pnpm', 'add', 'matrix-js-sdk']);
    });

    test('should build pnpm add command with global flag', () => {
      expect(buildInstallCommand('pnpm', null, true, false)).toEqual(['pnpm', 'add', '-g', 'matrix-js-sdk']);
    });

    test('should build pnpm add command with dev flag', () => {
      expect(buildInstallCommand('pnpm', null, false, true)).toEqual(['pnpm', 'add', '-D', 'matrix-js-sdk']);
    });

    test('should throw error for unknown package manager', () => {
      expect(() => buildInstallCommand('unknown', null, false, false)).toThrow('未知的包管理器');
    });
  });

  describe('installMatrixJsSdk function', () => {
    let resolveSpy;
    
    beforeEach(() => {
      execSync.mockReset();
      fs.existsSync.mockReset();
      resolveSpy = jest.spyOn(require, 'resolve');
    });
    
    afterEach(() => {
      resolveSpy.mockRestore();
    });

    test('should exit 0 in checkOnly mode when installed', () => {
      resolveSpy.mockReturnValue('/matrix-js-sdk');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '32.0.0' }));
      expect(() => installMatrixJsSdk({ checkOnly: true, global: false })).toThrow('Process exit with code 0');
    });

    test('should exit 0 in checkOnly mode when not installed', () => {
      resolveSpy.mockImplementation(() => { throw new Error('not found'); });
      expect(() => installMatrixJsSdk({ checkOnly: true, global: false })).toThrow('Process exit with code 0');
    });

    test('should exit 0 when already installed', () => {
      resolveSpy.mockReturnValue('/matrix-js-sdk');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '32.0.0' }));
      expect(() => installMatrixJsSdk({ checkOnly: false, global: false, packageManager: null, version: null, saveDev: false })).toThrow('Process exit with code 0');
    });

    test('should exit 3 when no package manager available', () => {
      resolveSpy.mockImplementation(() => { throw new Error('not found'); });
      fs.existsSync.mockReturnValue(false);
      execSync.mockImplementation(() => { throw new Error('not found'); });
      expect(() => installMatrixJsSdk({ checkOnly: false, global: false, packageManager: null, version: null, saveDev: false })).toThrow('Process exit with code 3');
      expect(mockConsole.errors).toContainEqual(['错误: 未找到可用的包管理器 (npm/yarn/pnpm)']);
    });

    test('should warn when global and saveDev both set', () => {
      resolveSpy.mockImplementation(() => { throw new Error('not found'); });
      fs.existsSync.mockReturnValue(false);
      execSync.mockImplementation((cmd) => {
        if (cmd === 'npm --version') return '10.0.0';
        throw new Error('not found');
      });
      try { installMatrixJsSdk({ checkOnly: false, global: true, packageManager: 'npm', version: null, saveDev: true }); } catch (e) {}
      expect(mockConsole.warns).toContainEqual(['警告: --save-dev 在全局安装模式下无效，将被忽略']);
    });

    test('should successfully install with npm', () => {
      let callCount = 0;
      resolveSpy.mockImplementation(() => {
        callCount++;
        if (callCount > 2) return '/matrix-js-sdk';
        throw new Error('not found');
      });
      execSync.mockReturnValue('');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '32.0.0' }));
      const result = installMatrixJsSdk({ checkOnly: false, global: false, packageManager: 'npm', version: null, saveDev: false });
      expect(result.action).toBe('installed');
      expect(result.package_manager).toBe('npm');
    });

    test('should exit 2 when install fails', () => {
      resolveSpy.mockImplementation(() => { throw new Error('not found'); });
      fs.existsSync.mockReturnValue(false);
      execSync.mockImplementation((cmd) => {
        if (cmd === 'npm --version') return '10.0.0';
        throw new Error('Install failed');
      });
      expect(() => installMatrixJsSdk({ checkOnly: false, global: false, packageManager: 'npm', version: null, saveDev: false })).toThrow('Process exit with code 2');
    });

    test('should use specified package manager', () => {
      resolveSpy.mockImplementation(() => { throw new Error('not found'); });
      fs.existsSync.mockReturnValue(false);
      execSync.mockReturnValue('');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '32.0.0' }));
      const result = installMatrixJsSdk({ checkOnly: false, global: false, packageManager: 'pnpm', version: null, saveDev: false });
      expect(result.package_manager).toBe('pnpm');
    });

    test('should install specific version', () => {
      resolveSpy.mockImplementation(() => { throw new Error('not found'); });
      fs.existsSync.mockReturnValue(false);
      execSync.mockReturnValue('');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '32.0.0' }));
      installMatrixJsSdk({ checkOnly: false, global: false, packageManager: 'npm', version: '31.0.0', saveDev: false });
      expect(execSync).toHaveBeenCalledWith(expect.stringContaining('matrix-js-sdk@31.0.0'), expect.any(Object));
    });

    test('should handle global install', () => {
      resolveSpy.mockImplementation(() => { throw new Error('not found'); });
      execSync.mockReturnValue('/usr/lib/node_modules');
      fs.readFileSync.mockReturnValue(JSON.stringify({ version: '32.0.0' }));
      const result = installMatrixJsSdk({ checkOnly: false, global: true, packageManager: 'npm', version: null, saveDev: false });
      expect(result.global).toBe(true);
    });
  });
});