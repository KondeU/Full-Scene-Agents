/**
 * get_chat_history.test.js
 * 
 * Test suite for get_chat_history.js - Chat history retrieval
 * Coverage target: >80% branches, functions, lines, statements
 */

jest.mock('./_common', () => ({
  resolveAccessToken: jest.fn()
}));

const { parseArgs, getChatHistory, formatMessage } = require('./get_chat_history');

describe('get_chat_history.js', () => {
  let mockClient;
  let mockSdk;
  let mockConsole;
  
  beforeEach(() => {
    mockConsole = global.mockConsole();
    
    mockSdk = require('matrix-js-sdk');
    mockClient = mockSdk.createClient();
    mockClient.createMessagesRequest.mockResolvedValue({
      chunk: [],
      start: 'start_token',
      end: 'end_token'
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

    test('should parse -r short option', () => {
      const argv = ['node', 'script', '-r', '!room:example.com'];

      const result = parseArgs(argv);

      expect(result.roomId).toBe('!room:example.com');
    });

    test('should parse --homeserver option', () => {
      const argv = ['node', 'script', '-r', '!room', '--homeserver', 'http://custom:8008'];

      const result = parseArgs(argv);

      expect(result.homeserver).toBe('http://custom:8008');
    });

    test('should parse --access-token option', () => {
      const argv = ['node', 'script', '-r', '!room', '--access-token', 'token123'];

      const result = parseArgs(argv);

      expect(result.accessToken).toBe('token123');
    });

    test('should parse --limit option', () => {
      const argv = ['node', 'script', '-r', '!room', '--limit', '100'];

      const result = parseArgs(argv);

      expect(result.limit).toBe(100);
    });

    test('should parse -n short option for limit', () => {
      const argv = ['node', 'script', '-r', '!room', '-n', '200'];

      const result = parseArgs(argv);

      expect(result.limit).toBe(200);
    });

    test('should exit 1 for invalid limit (non-integer)', () => {
      const argv = ['node', 'script', '-r', '!room', '--limit', 'abc'];
      
      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --limit 参数必须是正整数']);
    });

    test('should exit 1 for limit less than 1', () => {
      const argv = ['node', 'script', '-r', '!room', '--limit', '0'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --limit 参数必须是正整数']);
    });

    test('should exit 1 for negative limit', () => {
      const argv = ['node', 'script', '-r', '!room', '--limit', '-10'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');
    });

    test('should parse --from option', () => {
      const argv = ['node', 'script', '-r', '!room', '--from', 'token123'];

      const result = parseArgs(argv);

      expect(result.from).toBe('token123');
    });

    test('should parse --direction b', () => {
      const argv = ['node', 'script', '-r', '!room', '--direction', 'b'];

      const result = parseArgs(argv);

      expect(result.direction).toBe('b');
    });

    test('should parse --direction f', () => {
      const argv = ['node', 'script', '-r', '!room', '--direction', 'f'];

      const result = parseArgs(argv);

      expect(result.direction).toBe('f');
    });

    test('should parse -d short option for direction', () => {
      const argv = ['node', 'script', '-r', '!room', '-d', 'f'];

      const result = parseArgs(argv);

      expect(result.direction).toBe('f');
    });

    test('should exit 1 for invalid direction', () => {
      const argv = ['node', 'script', '-r', '!room', '--direction', 'invalid'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --direction 参数必须是 \'b\' (backward) 或 \'f\' (forward)']);
    });

    test('should parse --only-text flag', () => {
      const argv = ['node', 'script', '-r', '!room', '--only-text'];

      const result = parseArgs(argv);

      expect(result.onlyText).toBe(true);
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
      const argv = ['node', 'script', '-r', '!room', '--homeserver'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --homeserver 参数需要一个值']);
    });

    test('should exit 1 when --limit is last argument without value', () => {
      const argv = ['node', 'script', '-r', '!room', '--limit'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --limit 参数需要一个值']);
    });

    test('should exit 1 when --direction is last argument without value', () => {
      const argv = ['node', 'script', '-r', '!room', '--direction'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --direction 参数需要一个值']);
    });

    test('should exit 1 when --from is last argument without value', () => {
      const argv = ['node', 'script', '-r', '!room', '--from'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --from 参数需要一个值']);
    });

    test('should have default values', () => {
      const argv = ['node', 'script', '-r', '!room'];

      const result = parseArgs(argv);
      
      expect(result.homeserver).toBe('http://140.143.96.124:8888');
      expect(result.limit).toBe(50);
      expect(result.direction).toBe('b');
      expect(result.onlyText).toBe(false);
      expect(result.from).toBeNull();
    });
  });

  describe('formatMessage', () => {
    test('should format m.room.message text event', () => {
      const event = {
        event_id: '$event1',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.text',
          body: 'Hello world'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');

      expect(result.event_id).toBe('$event1');
      expect(result.type).toBe('m.room.message');
      expect(result.sender).toBe('@user:example.com');
      expect(result.msgtype).toBe('m.text');
      expect(result.body).toBe('Hello world');
      expect(result.is_own).toBe(false);
    });

    test('should format own message correctly', () => {
      const event = {
        event_id: '$event2',
        type: 'm.room.message',
        sender: '@test:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.text',
          body: 'My message'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.is_own).toBe(true);
    });

    test('should format message with formatted_body', () => {
      const event = {
        event_id: '$event3',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.text',
          body: 'Plain text',
          format: 'org.matrix.custom.html',
          formatted_body: '<b>HTML</b>'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.formatted_body).toBe('<b>HTML</b>');
    });

    test('should format m.notice message', () => {
      const event = {
        event_id: '$event4',
        type: 'm.room.message',
        sender: '@bot:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.notice',
          body: 'Bot notice'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.msgtype).toBe('m.notice');
      expect(result.body).toBe('Bot notice');
    });

    test('should format m.image message with info', () => {
      const event = {
        event_id: '$event5',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.image',
          body: 'image.jpg',
          url: 'mxc://example.com/image',
          info: {
            mimetype: 'image/jpeg',
            size: 1024,
            w: 100,
            h: 200
          }
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.msgtype).toBe('m.image');
      expect(result.url).toBe('mxc://example.com/image');
      expect(result.info.mimetype).toBe('image/jpeg');
      expect(result.info.w).toBe(100);
      expect(result.info.h).toBe(200);
    });

    test('should format m.file message', () => {
      const event = {
        event_id: '$event6',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.file',
          body: 'document.pdf',
          url: 'mxc://example.com/file'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.msgtype).toBe('m.file');
      expect(result.url).toBe('mxc://example.com/file');
    });

    test('should format m.video message', () => {
      const event = {
        event_id: '$event7',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.video',
          body: 'video.mp4',
          url: 'mxc://example.com/video'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.msgtype).toBe('m.video');
    });

    test('should format m.audio message', () => {
      const event = {
        event_id: '$event8',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.audio',
          body: 'audio.mp3',
          url: 'mxc://example.com/audio'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.msgtype).toBe('m.audio');
    });

    test('should format m.room.member event', () => {
      const event = {
        event_id: '$event9',
        type: 'm.room.member',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          membership: 'join',
          displayname: 'User Name'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.type).toBe('m.room.member');
      expect(result.membership).toBe('join');
      expect(result.displayname).toBe('User Name');
    });

    test('should format m.room.name event', () => {
      const event = {
        event_id: '$event10',
        type: 'm.room.name',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          name: 'Room Name'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.type).toBe('m.room.name');
      expect(result.name).toBe('Room Name');
    });

    test('should format m.room.topic event', () => {
      const event = {
        event_id: '$event11',
        type: 'm.room.topic',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          topic: 'Room Topic'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.type).toBe('m.room.topic');
      expect(result.topic).toBe('Room Topic');
    });

    test('should handle event without content', () => {
      const event = {
        event_id: '$event12',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.body).toBe('');
    });

    test('should handle null content', () => {
      const event = {
        event_id: '$event13',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: null
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.body).toBe('');
    });

    test('should handle image without info', () => {
      const event = {
        event_id: '$event14',
        type: 'm.room.message',
        sender: '@user:example.com',
        origin_server_ts: 1234567890000,
        content: {
          msgtype: 'm.image',
          body: 'image.jpg',
          url: 'mxc://example.com/image'
        }
      };
      
      const result = formatMessage(event, '@test:example.com');
      
      expect(result.url).toBe('mxc://example.com/image');
      expect(result.info).toBeUndefined();
    });
  });

  describe('getChatHistory function', () => {
    test('should exit 1 when roomId is missing', async () => {
      await expect(getChatHistory({
        roomId: null,
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      })).rejects.toThrow('Process exit with code 1');
      
      expect(mockConsole.errors).toContainEqual(['错误: 缺少必填参数 --room-id']);
    });

    test('should exit 1 when accessToken is missing', async () => {
      await expect(getChatHistory({
        roomId: '!room:example.com',
        accessToken: null,
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      })).rejects.toThrow('Process exit with code 1');
      
      expect(mockConsole.errors[0][0]).toContain('缺少 access_token');
    });

    test('should exit 3 when authentication fails (401)', async () => {
      const authError = new Error('Unauthorized');
      authError.statusCode = 401;
      mockClient.whoami.mockRejectedValue(authError);
      
      await expect(getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'bad_token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      })).rejects.toThrow('Process exit with code 3');
      
      expect(mockConsole.errors).toContainEqual(['错误: 认证失败，access_token 无效或已过期']);
    });

    test('should exit 2 when connection fails', async () => {
      const connError = new Error('Connection refused');
      mockClient.whoami.mockRejectedValue(connError);
      
      await expect(getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      })).rejects.toThrow('Process exit with code 2');
    });

    test('should exit 4 when room does not exist (404)', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      
      const roomError = new Error('Room not found');
      roomError.statusCode = 404;
      mockClient.createMessagesRequest.mockRejectedValue(roomError);
      
      await expect(getChatHistory({
        roomId: '!invalid:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      })).rejects.toThrow('Process exit with code 4');
    });

    test('should exit 4 when room permission denied (403)', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      
      const roomError = new Error('Forbidden');
      roomError.statusCode = 403;
      mockClient.createMessagesRequest.mockRejectedValue(roomError);
      
      await expect(getChatHistory({
        roomId: '!private:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      })).rejects.toThrow('Process exit with code 4');
    });

    test('should successfully get chat history', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: [
          {
            event_id: '$event1',
            type: 'm.room.message',
            sender: '@user:example.com',
            origin_server_ts: 1234567890000,
            content: { msgtype: 'm.text', body: 'Hello' }
          }
        ],
        start: 'start_token',
        end: 'end_token'
      });
      
      const result = await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false,
        from: null
      });
      
      expect(result.room_id).toBe('!room:example.com');
      expect(result.messages.length).toBe(1);
      expect(result.pagination.start).toBe('start_token');
      expect(result.pagination.has_next).toBe(true);
    });

    test('should limit messages to maximum 1000', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: [],
        start: 'start',
        end: 'end'
      });
      
      await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 2000,
        direction: 'b',
        onlyText: false
      });
      
      expect(mockClient.createMessagesRequest).toHaveBeenCalledWith(
        '!room:example.com',
        undefined,
        1000,
        'b'
      );
    });

    test('should filter only text messages when onlyText is true', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: [
          {
            event_id: '$event1',
            type: 'm.room.message',
            sender: '@user:example.com',
            origin_server_ts: 1234567890000,
            content: { msgtype: 'm.text', body: 'Text message' }
          },
          {
            event_id: '$event2',
            type: 'm.room.message',
            sender: '@user:example.com',
            origin_server_ts: 1234567890001,
            content: { msgtype: 'm.image', body: 'image.jpg', url: 'mxc://...' }
          },
          {
            event_id: '$event3',
            type: 'm.room.member',
            sender: '@user:example.com',
            origin_server_ts: 1234567890002,
            content: { membership: 'join' }
          },
          {
            event_id: '$event4',
            type: 'm.room.message',
            sender: '@user:example.com',
            origin_server_ts: 1234567890003,
            content: { msgtype: 'm.notice', body: 'Notice' }
          }
        ],
        start: 'start',
        end: 'end'
      });
      
      const result = await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: true
      });
      
      expect(result.messages.length).toBe(2);
      expect(result.messages[0].msgtype).toBe('m.text');
      expect(result.messages[1].msgtype).toBe('m.notice');
    });

    test('should handle empty chunk', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: [],
        start: 'start',
        end: null
      });
      
      const result = await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      });
      
      expect(result.messages.length).toBe(0);
      expect(result.pagination.has_next).toBe(false);
    });

    test('should handle null chunk', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: null,
        start: 'start',
        end: 'end'
      });
      
      const result = await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      });
      
      expect(result.messages.length).toBe(0);
    });

    test('should calculate stats correctly', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: [
          {
            event_id: '$event1',
            type: 'm.room.message',
            sender: '@user1:example.com',
            origin_server_ts: 1234567890000,
            content: { msgtype: 'm.text', body: 'Hello' }
          },
          {
            event_id: '$event2',
            type: 'm.room.message',
            sender: '@user2:example.com',
            origin_server_ts: 1234567890001,
            content: { msgtype: 'm.text', body: 'World' }
          },
          {
            event_id: '$event3',
            type: 'm.room.message',
            sender: '@user1:example.com',
            origin_server_ts: 1234567890002,
            content: { msgtype: 'm.text', body: 'Again' }
          }
        ],
        start: 'start',
        end: 'end'
      });
      
      const result = await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false
      });
      
      expect(result.stats.total).toBe(3);
      expect(result.stats.by_type['m.room.message']).toBe(3);
      expect(result.stats.by_sender['@user1:example.com']).toBe(2);
      expect(result.stats.by_sender['@user2:example.com']).toBe(1);
    });

    test('should use forward direction', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: [],
        start: 'start',
        end: 'end'
      });
      
      await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'f',
        onlyText: false
      });
      
      expect(mockClient.createMessagesRequest).toHaveBeenCalledWith(
        '!room:example.com',
        undefined,
        50,
        'f'
      );
    });

    test('should use from token for pagination', async () => {
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.createMessagesRequest.mockResolvedValue({
        chunk: [],
        start: 'start',
        end: 'end'
      });
      
      await getChatHistory({
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        limit: 50,
        direction: 'b',
        onlyText: false,
        from: 'previous_token'
      });
      
      expect(mockClient.createMessagesRequest).toHaveBeenCalledWith(
        '!room:example.com',
        'previous_token',
        50,
        'b'
      );
    });
  });
});