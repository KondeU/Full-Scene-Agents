/**
 * get_member_presence.test.js
 *
 * Test suite for get_member_presence.js - Member presence status retrieval
 * Coverage target: >80% branches, functions, lines, statements
 */

jest.mock('./_common', () => ({
  resolveAccessToken: jest.fn()
}));

const { parseArgs, getMemberPresence } = require('./get_member_presence');

describe('get_member_presence.js', () => {
  let mockClient;
  let mockSdk;
  let mockConsole;

  beforeEach(() => {
    mockConsole = global.mockConsole();

    mockSdk = require('matrix-js-sdk');
    mockClient = mockSdk.createClient();
    mockClient.roomState.mockResolvedValue([
      {
        type: 'm.room.member',
        state_key: '@user1:example.com',
        content: { membership: 'join', displayname: 'User One' }
      },
      {
        type: 'm.room.member',
        state_key: '@user2:example.com',
        content: { membership: 'join', displayname: 'User Two' }
      }
    ]);
    mockClient.getPresence.mockResolvedValue({
      presence: 'online',
      last_active_ago: 1000
    });

    const common = require('./_common');
    common.resolveAccessToken.mockReturnValue('resolved_token');
  });

  afterEach(() => {
    mockConsole.restore();
    jest.clearAllMocks();
  });

  describe('parseArgs', () => {
    test('should parse --room-id correctly', () => {
      const argv = ['node', 'script', '--room-id', '!room:example.com'];

      const result = parseArgs(argv);

      expect(result.roomId).toBe('!room:example.com');
    });

    test('should parse --homeserver option', () => {
      const argv = ['node', 'script', '--room-id', '!room', '--homeserver', 'http://custom:8008'];

      const result = parseArgs(argv);

      expect(result.homeserver).toBe('http://custom:8008');
    });

    test('should parse --access-token option', () => {
      const argv = ['node', 'script', '--room-id', '!room', '--access-token', 'token123'];

      const result = parseArgs(argv);

      expect(result.accessToken).toBe('token123');
    });

    test('should show help with --help', () => {
      const argv = ['node', 'script', '--help'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 0');
    });

    test('should show help with -h', () => {
      const argv = ['node', 'script', '-h'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 0');
    });

    test('should exit 1 for unknown argument', () => {
      const argv = ['node', 'script', '--unknown'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');
    });

    test('should exit 1 when --room-id is last argument without value', () => {
      const argv = ['node', 'script', '--room-id'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --room-id 参数需要一个值']);
    });

    test('should exit 1 when --homeserver is last argument without value', () => {
      const argv = ['node', 'script', '--room-id', '!room', '--homeserver'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --homeserver 参数需要一个值']);
    });

    test('should exit 1 when --access-token is last argument without value', () => {
      const argv = ['node', 'script', '--room-id', '!room', '--access-token'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --access-token 参数需要一个值']);
    });

    test('should have default values', () => {
      const argv = ['node', 'script', '--room-id', '!room'];

      const result = parseArgs(argv);

      expect(result.homeserver).toBe('http://140.143.96.124:8888');
      expect(result.accessToken).toBeNull();
    });
  });

  describe('getMemberPresence function', () => {
    test('should exit 1 when roomId is missing', async () => {
      await expect(getMemberPresence({
        roomId: null,
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: 缺少必填参数 --room-id']);
    });

    test('should exit 1 when accessToken is missing', async () => {
      await expect(getMemberPresence({
        roomId: '!room:example.com',
        accessToken: null,
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 1');

      expect(mockConsole.errors[0][0]).toContain('缺少 access_token');
    });

    test('should exit 3 when authentication fails (401)', async () => {
      const authError = new Error('Unauthorized');
      authError.statusCode = 401;
      mockClient.whoami.mockRejectedValue(authError);

      await expect(getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'bad_token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 3');

      expect(mockConsole.errors).toContainEqual(['错误: 认证失败，access_token 无效或已过期']);
    });

    test('should exit 3 when authentication fails (403)', async () => {
      const authError = new Error('Forbidden');
      authError.statusCode = 403;
      mockClient.whoami.mockRejectedValue(authError);

      await expect(getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'bad_token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 3');
    });

    test('should exit 2 when connection fails', async () => {
      const connError = new Error('Connection refused');
      mockClient.whoami.mockRejectedValue(connError);

      await expect(getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 2');
    });

    test('should exit 4 when room does not exist (404)', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });

      const roomError = new Error('Room not found');
      roomError.statusCode = 404;
      mockClient.roomState.mockRejectedValue(roomError);

      await expect(getMemberPresence({
        roomId: '!invalid:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors).toContainEqual(['错误: 房间不存在']);
    });

    test('should exit 4 when room permission denied (403)', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });

      const roomError = new Error('Forbidden');
      roomError.statusCode = 403;
      mockClient.roomState.mockRejectedValue(roomError);

      await expect(getMemberPresence({
        roomId: '!private:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors).toContainEqual(['错误: 房间不存在或无权限访问']);
    });

    test('should exit 4 for other room state errors', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });

      const roomError = new Error('Server error');
      roomError.statusCode = 500;
      mockClient.roomState.mockRejectedValue(roomError);

      await expect(getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 4');
    });

    test('should successfully get member presence', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@self:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@self:example.com',
          content: { membership: 'join', displayname: 'Self' }
        },
        {
          type: 'm.room.member',
          state_key: '@user1:example.com',
          content: { membership: 'join', displayname: 'User One' }
        },
        {
          type: 'm.room.member',
          state_key: '@user2:example.com',
          content: { membership: 'join', displayname: 'User Two' }
        }
      ]);

      mockClient.getPresence
        .mockResolvedValueOnce({ presence: 'online', last_active_ago: 100 })
        .mockResolvedValueOnce({ presence: 'offline', last_active_ago: 5000 });

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.room_id).toBe('!room:example.com');
      expect(result.members.length).toBe(2);
      expect(result.members[0].mxid).toBe('@user1:example.com');
      expect(result.members[0].presence).toBe('online');
      expect(result.members[1].presence).toBe('offline');
      expect(result.summary.total).toBe(2);
    });

    test('should skip self member', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@self:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@self:example.com',
          content: { membership: 'join', displayname: 'Self' }
        },
        {
          type: 'm.room.member',
          state_key: '@other:example.com',
          content: { membership: 'join', displayname: 'Other' }
        }
      ]);

      mockClient.getPresence.mockResolvedValue({ presence: 'online', last_active_ago: 0 });

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members.length).toBe(1);
      expect(result.members[0].mxid).toBe('@other:example.com');
    });

    test('should filter only join members', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@user1:example.com',
          content: { membership: 'join', displayname: 'User One' }
        },
        {
          type: 'm.room.member',
          state_key: '@user2:example.com',
          content: { membership: 'leave', displayname: 'User Two' }
        },
        {
          type: 'm.room.member',
          state_key: '@user3:example.com',
          content: { membership: 'invite', displayname: 'User Three' }
        },
        {
          type: 'm.room.power_levels',
          state_key: '',
          content: { users: {} }
        }
      ]);

      mockClient.getPresence.mockResolvedValue({ presence: 'online', last_active_ago: 0 });

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members.length).toBe(1);
      expect(result.members[0].mxid).toBe('@user1:example.com');
    });

    test('should handle missing displayname', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@user:example.com',
          content: { membership: 'join' }
        }
      ]);

      mockClient.getPresence.mockResolvedValue({ presence: 'online', last_active_ago: 0 });

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members[0].display_name).toBe('@user:example.com');
    });

    test('should handle missing avatar_url', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@user:example.com',
          content: { membership: 'join', displayname: 'User' }
        }
      ]);

      mockClient.getPresence.mockResolvedValue({ presence: 'online', last_active_ago: 0 });

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members[0].avatar_url).toBeUndefined();
    });

    test('should handle getPresence failure gracefully', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@user:example.com',
          content: { membership: 'join', displayname: 'User' }
        }
      ]);

      mockClient.getPresence.mockRejectedValue(new Error('Presence error'));

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members[0].presence).toBe('offline');
      expect(result.members[0].last_active_ago).toBeNull();
    });

    test('should handle missing presence data', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@user:example.com',
          content: { membership: 'join', displayname: 'User' }
        }
      ]);

      mockClient.getPresence.mockResolvedValue({});

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members[0].presence).toBe('offline');
      expect(result.members[0].last_active_ago).toBeNull();
    });

    test('should calculate summary correctly', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.member',
          state_key: '@user1:example.com',
          content: { membership: 'join' }
        },
        {
          type: 'm.room.member',
          state_key: '@user2:example.com',
          content: { membership: 'join' }
        },
        {
          type: 'm.room.member',
          state_key: '@user3:example.com',
          content: { membership: 'join' }
        }
      ]);

      mockClient.getPresence
        .mockResolvedValueOnce({ presence: 'online', last_active_ago: 100 })
        .mockResolvedValueOnce({ presence: 'unavailable', last_active_ago: 200 })
        .mockResolvedValueOnce({ presence: 'offline', last_active_ago: 300 });

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.summary.total).toBe(3);
      expect(result.summary.online).toBe(1);
      expect(result.summary.unavailable).toBe(1);
      expect(result.summary.offline).toBe(1);
    });

    test('should warn when room has no members', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(mockConsole.errors).toContainEqual(['警告: 房间内无成员']);
      expect(result.members.length).toBe(0);
    });

    test('should handle empty room state', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members.length).toBe(0);
      expect(result.summary.total).toBe(0);
    });

    test('should exit 4 when room state is null', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue(null);

      await expect(getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 4');
    });

    test('should handle room state with non-member events', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([
        {
          type: 'm.room.name',
          state_key: '',
          content: { name: 'Room Name' }
        },
        {
          type: 'm.room.topic',
          state_key: '',
          content: { topic: 'Topic' }
        },
        {
          type: 'm.room.power_levels',
          state_key: '',
          content: {}
        }
      ]);

      const result = await getMemberPresence({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.members.length).toBe(0);
    });
  });
});
