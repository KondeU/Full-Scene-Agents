/**
 * obtain_access_token.test.js
 *
 * Test suite for obtain_access_token.js - AccessToken acquisition
 * Coverage target: >80% branches, functions, lines, statements
 */

const fs = require('fs');

jest.mock('fs');

const { parseArgs, obtainAccessToken, printHelp } = require('./obtain_access_token');

describe('obtain_access_token.js', () => {
  let mockClient;
  let mockSdk;
  let mockConsole;

  beforeEach(() => {
    mockConsole = global.mockConsole();

    mockSdk = require('matrix-js-sdk');
    mockClient = mockSdk.createClient();
    mockClient.login.mockResolvedValue({ access_token: 'new_token_123' });

    fs.existsSync.mockReset();
    fs.readFileSync.mockReset();
    fs.writeFileSync.mockReset();
  });

  afterEach(() => {
    mockConsole.restore();
    jest.clearAllMocks();
  });

  describe('parseArgs', () => {
    test('should parse --file option', () => {
      const argv = ['node', 'script', '--file', '/custom/config.json'];
      const result = parseArgs(argv);
      expect(result.configFile).toBe('/custom/config.json');
    });

    test('should parse --user-id option', () => {
      const argv = ['node', 'script', '--user-id', '@user:example.com'];
      const result = parseArgs(argv);
      expect(result.userId).toBe('@user:example.com');
      expect(result.useArgs).toBe(true);
    });

    test('should parse --password option', () => {
      const argv = ['node', 'script', '--password', 'mypassword'];
      const result = parseArgs(argv);
      expect(result.password).toBe('mypassword');
      expect(result.useArgs).toBe(true);
    });

    test('should parse --homeserver option', () => {
      const argv = ['node', 'script', '--homeserver', 'http://server:8008'];
      const result = parseArgs(argv);
      expect(result.homeserver).toBe('http://server:8008');
      expect(result.useArgs).toBe(true);
    });

    test('should parse --device-name option', () => {
      const argv = ['node', 'script', '--device-name', 'MyDevice'];
      const result = parseArgs(argv);
      expect(result.deviceName).toBe('MyDevice');
      expect(result.useArgs).toBe(true);
    });

    test('should set useArgs true when any credential arg is provided', () => {
      const argv = ['node', 'script', '--user-id', '@user:example.com'];
      const result = parseArgs(argv);
      expect(result.useArgs).toBe(true);
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

    test('should exit 1 when --file is last argument without value', () => {
      const argv = ['node', 'script', '--file'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: --file 参数需要一个值']);
    });

    test('should exit 1 when --user-id is last argument without value', () => {
      const argv = ['node', 'script', '--user-id'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: --user-id 参数需要一个值']);
    });

    test('should exit 1 when --password is last argument without value', () => {
      const argv = ['node', 'script', '--password'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: --password 参数需要一个值']);
    });

    test('should exit 1 when --homeserver is last argument without value', () => {
      const argv = ['node', 'script', '--homeserver'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: --homeserver 参数需要一个值']);
    });

    test('should exit 1 when --device-name is last argument without value', () => {
      const argv = ['node', 'script', '--device-name'];
      expect(() => parseArgs(argv)).toThrow('Process exit with code 1');
      expect(mockConsole.errors).toContainEqual(['错误: --device-name 参数需要一个值']);
    });

    test('should have default configFile ending with access_token.json', () => {
      const argv = ['node', 'script'];
      const result = parseArgs(argv);
      expect(result.configFile).toMatch(/access_token\.json$/);
    });

    test('should have null defaults for credential fields', () => {
      const argv = ['node', 'script'];
      const result = parseArgs(argv);
      expect(result.userId).toBeNull();
      expect(result.password).toBeNull();
      expect(result.homeserver).toBeNull();
      expect(result.deviceName).toBeNull();
      expect(result.useArgs).toBe(false);
    });
  });

  describe('obtainAccessToken function', () => {
    const MOCK_CONFIG_PATH = '/mock/access_token.json';

    test('should exit 4 when config file does not exist', async () => {
      fs.existsSync.mockReturnValue(false);

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors).toContainEqual(['错误: 配置文件不存在 - /mock/access_token.json']);
    });

    test('should exit 4 when config file parse fails', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue('invalid json {{{');

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 4');
    });

    test('should exit 4 when config file missing userId', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        password: 'pass',
        homeserver: 'http://server'
      }));

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors).toContainEqual(['错误: 配置文件缺少必要字段 (userId, password, homeserver)']);
    });

    test('should exit 4 when config file missing password', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        homeserver: 'http://server'
      }));

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 4');
    });

    test('should exit 4 when config file missing homeserver', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass'
      }));

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 4');
    });

    test('should exit 1 when args mode incomplete (missing password)', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server'
      }));

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: true,
        userId: '@user:example.com',
        password: null,
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: 使用参数模式时，--user-id、--password、--homeserver 必须同时提供，不允许部分指定']);
    });

    test('should exit 1 when args mode incomplete (missing homeserver)', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server'
      }));

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: true,
        userId: '@user:example.com',
        password: 'pass',
        homeserver: null
      })).rejects.toThrow('Process exit with code 1');
    });

    test('should exit 3 when login fails with 401', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'wrongpass',
        homeserver: 'http://server'
      }));

      const authError = new Error('Unauthorized');
      authError.statusCode = 401;
      mockClient.login.mockRejectedValue(authError);

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 3');

      expect(mockConsole.errors).toContainEqual(['错误: 认证失败，用户名或密码错误']);
    });

    test('should exit 3 when login fails with 403', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'wrongpass',
        homeserver: 'http://server'
      }));

      const authError = new Error('Forbidden');
      authError.statusCode = 403;
      mockClient.login.mockRejectedValue(authError);

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 3');
    });

    test('should exit 2 when login fails with other error', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server'
      }));

      const connError = new Error('Connection refused');
      mockClient.login.mockRejectedValue(connError);

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 2');

      expect(mockConsole.errors[0][0]).toContain('登录失败');
    });

    test('should exit 2 when login response has no access_token', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server'
      }));

      mockClient.login.mockResolvedValue({});

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 2');

      expect(mockConsole.errors).toContainEqual(['错误: 登录成功但未获取到 access_token']);
    });

    test('should successfully login and write token (config mode)', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server',
        deviceName: 'MyDevice'
      }));
      fs.writeFileSync.mockReturnValue();

      mockClient.login.mockResolvedValue({ access_token: 'new_token_abc' });

      const result = await obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      });

      expect(result.user_id).toBe('@user:example.com');
      expect(result.access_token).toBe('new_token_abc');
      expect(result.mode).toBe('config');
      expect(fs.writeFileSync).toHaveBeenCalled();
    });

    test('should successfully login with args mode', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@config:example.com',
        password: 'configpass',
        homeserver: 'http://config'
      }));
      fs.writeFileSync.mockReturnValue();

      mockClient.login.mockResolvedValue({ access_token: 'args_token_xyz' });

      const result = await obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: true,
        userId: '@args:example.com',
        password: 'argspass',
        homeserver: 'http://args',
        deviceName: 'ArgsDevice'
      });

      expect(result.user_id).toBe('@args:example.com');
      expect(result.access_token).toBe('args_token_xyz');
      expect(result.mode).toBe('args');
      expect(mockClient.login).toHaveBeenCalledWith('m.login.password', {
        user: '@args:example.com',
        password: 'argspass',
        initial_device_display_name: 'ArgsDevice'
      });
    });

    test('should use config deviceName when args mode without deviceName', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@config:example.com',
        password: 'configpass',
        homeserver: 'http://config',
        deviceName: 'ConfigDevice'
      }));
      fs.writeFileSync.mockReturnValue();

      mockClient.login.mockResolvedValue({ access_token: 'token' });

      await obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: true,
        userId: '@args:example.com',
        password: 'argspass',
        homeserver: 'http://args',
        deviceName: null
      });

      expect(mockClient.login).toHaveBeenCalledWith('m.login.password', {
        user: '@args:example.com',
        password: 'argspass',
        initial_device_display_name: 'ConfigDevice'
      });
    });

    test('should handle no deviceName at all', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server'
      }));
      fs.writeFileSync.mockReturnValue();

      mockClient.login.mockResolvedValue({ access_token: 'token' });

      await obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      });

      expect(mockClient.login).toHaveBeenCalledWith('m.login.password', {
        user: '@user:example.com',
        password: 'pass',
        initial_device_display_name: undefined
      });
    });

    test('should strip trailing slashes from homeserver', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server:8008///'
      }));
      fs.writeFileSync.mockReturnValue();

      mockClient.login.mockResolvedValue({ access_token: 'token' });

      const result = await obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      });

      expect(result.homeserver).toBe('http://server:8008');
      expect(mockSdk.createClient).toHaveBeenCalledWith({
        baseUrl: 'http://server:8008'
      });
    });

    test('should exit 4 when write file fails', async () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server'
      }));
      fs.writeFileSync.mockImplementation(() => {
        throw new Error('Write permission denied');
      });

      mockClient.login.mockResolvedValue({ access_token: 'token' });

      await expect(obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors[0][0]).toContain('写入配置文件失败');
    });

    test('should preserve existing config fields when writing', async () => {
      const originalConfig = {
        userId: '@user:example.com',
        password: 'pass',
        homeserver: 'http://server',
        deviceName: 'MyDevice',
        customField: 'customValue'
      };

      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify(originalConfig));

      const writtenConfig = {};
      fs.writeFileSync.mockImplementation((_path, content) => {
        writtenConfig.data = JSON.parse(content);
      });

      mockClient.login.mockResolvedValue({ access_token: 'new_token' });

      await obtainAccessToken({
        configFile: MOCK_CONFIG_PATH,
        useArgs: false
      });

      expect(writtenConfig.data.customField).toBe('customValue');
      expect(writtenConfig.data.accessToken).toBe('new_token');
    });
  });
});
