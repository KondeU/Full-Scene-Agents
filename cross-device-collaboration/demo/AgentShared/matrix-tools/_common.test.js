/**
 * _common.test.js
 * 
 * Test suite for _common.js - AccessToken resolution utility
 * Coverage target: >80% branches, functions, lines, statements
 * 
 * Note: __dirname cannot be mocked, so tests use actual module path
 */

const fs = require('fs');

jest.mock('fs');

describe('_common.js', () => {
  let resolveAccessToken;
  let originalEnv;
  let actualConfigPath;

  beforeEach(() => {
    jest.resetModules();
    originalEnv = process.env.MATRIX_ACCESS_TOKEN;
    delete process.env.MATRIX_ACCESS_TOKEN;
    jest.clearAllMocks();
    
    fs.existsSync.mockReset();
    fs.readFileSync.mockReset();
  });

  afterEach(() => {
    if (originalEnv !== undefined) {
      process.env.MATRIX_ACCESS_TOKEN = originalEnv;
    } else {
      delete process.env.MATRIX_ACCESS_TOKEN;
    }
  });

  describe('resolveAccessToken', () => {
    test('should return trimmed argToken when valid string provided', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken('  valid_token_123  ');
      
      expect(result).toBe('valid_token_123');
    });

    test('should return null when argToken is empty string', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken('');
      
      expect(result).toBeNull();
    });

    test('should return null when argToken is whitespace only', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken('   ');
      
      expect(result).toBeNull();
    });

    test('should return null when argToken is null', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return null when argToken is undefined', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(undefined);
      
      expect(result).toBeNull();
    });

    test('should return null when argToken is number', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(123);
      
      expect(result).toBeNull();
    });

    test('should return null when argToken is object', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken({ token: 'test' });
      
      expect(result).toBeNull();
    });

    test('should return null when access_token.json does not exist', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return null when access_token.json parse fails', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue('invalid json');
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return null when accessToken field is missing in json', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({ userId: 'test' }));
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return null when accessToken is empty string in json', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({ accessToken: '' }));
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return null when accessToken is whitespace in json', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({ accessToken: '   ' }));
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return null when accessToken is number in json', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({ accessToken: 123 }));
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return environment variable when no argToken and no valid json', () => {
      fs.existsSync.mockReturnValue(false);
      process.env.MATRIX_ACCESS_TOKEN = '  env_token_789  ';
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBe('env_token_789');
    });

    test('should prioritize argToken over json and env', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({ accessToken: 'file_token' }));
      process.env.MATRIX_ACCESS_TOKEN = 'env_token';
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken('arg_token');
      
      expect(result).toBe('arg_token');
    });

    test('should handle readFileSync throwing error gracefully', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockImplementation(() => {
        throw new Error('Read error');
      });
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should return null when all sources are empty', () => {
      fs.existsSync.mockReturnValue(false);
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should handle accessToken field as null in json', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({ accessToken: null }));
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should handle accessToken field as object in json', () => {
      fs.existsSync.mockReturnValue(true);
      fs.readFileSync.mockReturnValue(JSON.stringify({ accessToken: { value: 'test' } }));
      delete process.env.MATRIX_ACCESS_TOKEN;
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should handle empty environment variable', () => {
      fs.existsSync.mockReturnValue(false);
      process.env.MATRIX_ACCESS_TOKEN = '';
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBeNull();
    });

    test('should trim whitespace from environment variable', () => {
      fs.existsSync.mockReturnValue(false);
      process.env.MATRIX_ACCESS_TOKEN = '   trimmed_env_token   ';
      
      const { resolveAccessToken } = require('./_common');
      const result = resolveAccessToken(null);
      
      expect(result).toBe('trimmed_env_token');
    });
  });
});