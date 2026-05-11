/**
 * upload_file.test.js
 *
 * Test suite for upload_file.js - File upload to Matrix room
 * Coverage target: >80% branches, functions, lines, statements
 */

const path = require('path');

jest.mock('fs');
jest.mock('./_common', () => ({
  resolveAccessToken: jest.fn()
}));

const { parseArgs, getMimeTypeAndMsgtype, getImageDimensions, uploadFile } = require('./upload_file');

describe('upload_file.js', () => {
  let mockClient;
  let mockSdk;
  let mockFs;
  let mockConsole;

  beforeEach(() => {
    mockConsole = global.mockConsole();

    mockSdk = require('matrix-js-sdk');
    mockClient = mockSdk.createClient();
    mockClient.uploadContent.mockResolvedValue({ content_uri: 'mxc://example.com/test' });
    mockClient.sendEvent.mockResolvedValue({ event_id: '$event123' });

    mockFs = require('fs');
    mockFs.existsSync.mockReset();
    mockFs.readFileSync.mockReset();
    mockFs.statSync.mockReset();
  });

  afterEach(() => {
    mockConsole.restore();
    jest.clearAllMocks();
  });

  describe('parseArgs', () => {
    test('should parse --file and --room-id correctly', () => {
      const argv = ['node', 'script', '--file', '/test/image.jpg', '--room-id', '!room:example.com'];

      const result = parseArgs(argv);

      expect(result.filePath).toBe('/test/image.jpg');
      expect(result.roomId).toBe('!room:example.com');
    });

    test('should parse -f and -r short options', () => {
      const argv = ['node', 'script', '-f', '/test/file.pdf', '-r', '!room:example.com'];

      const result = parseArgs(argv);

      expect(result.filePath).toBe('/test/file.pdf');
      expect(result.roomId).toBe('!room:example.com');
    });

    test('should parse --homeserver option', () => {
      const argv = ['node', 'script', '-f', '/test/file', '-r', '!room', '--homeserver', 'http://custom:8008'];

      const result = parseArgs(argv);

      expect(result.homeserver).toBe('http://custom:8008');
    });

    test('should parse --access-token option', () => {
      const argv = ['node', 'script', '-f', '/test/file', '-r', '!room', '--access-token', 'token123'];

      const result = parseArgs(argv);

      expect(result.accessToken).toBe('token123');
    });

    test('should parse --as-attachment flag', () => {
      const argv = ['node', 'script', '-f', '/test/file', '-r', '!room', '--as-attachment'];

      const result = parseArgs(argv);

      expect(result.asAttachment).toBe(true);
    });

    test('should show help and exit 0 with --help', () => {
      const argv = ['node', 'script', '--help'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 0');

      expect(mockConsole.logs.length).toBeGreaterThan(0);
    });

    test('should show help and exit 0 with -h', () => {
      const argv = ['node', 'script', '-h'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 0');

      expect(mockConsole.logs.length).toBeGreaterThan(0);
    });

    test('should exit 1 for unknown argument', () => {
      const argv = ['node', 'script', '--unknown'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['未知参数: --unknown']);
    });

    test('should exit 1 when --file is last argument without value', () => {
      const argv = ['node', 'script', '--file'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --file 参数需要一个值']);
    });

    test('should exit 1 when --room-id is last argument without value', () => {
      const argv = ['node', 'script', '-f', '/file', '--room-id'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --room-id 参数需要一个值']);
    });

    test('should exit 1 when --homeserver is last argument without value', () => {
      const argv = ['node', 'script', '-f', '/file', '-r', '!room', '--homeserver'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --homeserver 参数需要一个值']);
    });

    test('should exit 1 when --access-token is last argument without value', () => {
      const argv = ['node', 'script', '-f', '/file', '-r', '!room', '--access-token'];

      expect(() => {
        parseArgs(argv);
      }).toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: --access-token 参数需要一个值']);
    });

    test('should have default values', () => {
      const argv = ['node', 'script', '-f', '/file', '-r', '!room'];

      const result = parseArgs(argv);

      expect(result.homeserver).toBe('http://140.143.96.124:8888');
      expect(result.asAttachment).toBe(false);
    });
  });

  describe('getMimeTypeAndMsgtype', () => {
    test('should return image/jpeg for .jpg file', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.jpg', false);

      expect(result.mimeType).toBe('image/jpeg');
      expect(result.msgtype).toBe('m.image');
    });

    test('should return image/png for .png file', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.png', false);

      expect(result.mimeType).toBe('image/png');
      expect(result.msgtype).toBe('m.image');
    });

    test('should return video/mp4 for .mp4 file', () => {
      const result = getMimeTypeAndMsgtype('/path/to/video.mp4', false);

      expect(result.mimeType).toBe('video/mp4');
      expect(result.msgtype).toBe('m.video');
    });

    test('should return audio/mpeg for .mp3 file', () => {
      const result = getMimeTypeAndMsgtype('/path/to/audio.mp3', false);

      expect(result.mimeType).toBe('audio/mpeg');
      expect(result.msgtype).toBe('m.audio');
    });

    test('should return application/pdf for .pdf file', () => {
      const result = getMimeTypeAndMsgtype('/path/to/doc.pdf', false);

      expect(result.mimeType).toBe('application/pdf');
      expect(result.msgtype).toBe('m.file');
    });

    test('should return application/octet-stream for unknown extension', () => {
      const result = getMimeTypeAndMsgtype('/path/to/file.unknownext', false);

      expect(result.mimeType).toBe('application/octet-stream');
      expect(result.msgtype).toBe('m.file');
    });

    test('should force m.file when asAttachment is true for image', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.jpg', true);

      expect(result.mimeType).toBe('image/jpeg');
      expect(result.msgtype).toBe('m.file');
    });

    test('should return correct mime type for .jpeg', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.jpeg', false);

      expect(result.mimeType).toBe('image/jpeg');
    });

    test('should return correct mime type for .gif', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.gif', false);

      expect(result.mimeType).toBe('image/gif');
    });

    test('should return correct mime type for .webp', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.webp', false);

      expect(result.mimeType).toBe('image/webp');
    });

    test('should return correct mime type for .json', () => {
      const result = getMimeTypeAndMsgtype('/path/to/data.json', false);

      expect(result.mimeType).toBe('application/json');
    });

    test('should return correct mime type for .zip', () => {
      const result = getMimeTypeAndMsgtype('/path/to/archive.zip', false);

      expect(result.mimeType).toBe('application/zip');
    });

    test('should return correct mime type for .txt', () => {
      const result = getMimeTypeAndMsgtype('/path/to/file.txt', false);

      expect(result.mimeType).toBe('text/plain');
    });

    test('should return correct mime type for .bmp', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.bmp', false);
      expect(result.mimeType).toBe('image/bmp');
      expect(result.msgtype).toBe('m.image');
    });

    test('should return correct mime type for .svg', () => {
      const result = getMimeTypeAndMsgtype('/path/to/image.svg', false);
      expect(result.mimeType).toBe('image/svg+xml');
    });

    test('should return correct mime type for .webm (video)', () => {
      const result = getMimeTypeAndMsgtype('/path/to/video.webm', false);
      expect(result.mimeType).toBe('video/webm');
      expect(result.msgtype).toBe('m.video');
    });

    test('should return correct mime type for .wav (audio)', () => {
      const result = getMimeTypeAndMsgtype('/path/to/audio.wav', false);
      expect(result.mimeType).toBe('audio/wav');
      expect(result.msgtype).toBe('m.audio');
    });

    test('should return correct mime type for .doc', () => {
      const result = getMimeTypeAndMsgtype('/path/to/document.doc', false);
      expect(result.mimeType).toBe('application/msword');
    });

    test('should return correct mime type for .html', () => {
      const result = getMimeTypeAndMsgtype('/path/to/page.html', false);
      expect(result.mimeType).toBe('text/html');
    });

    test('should return correct mime type for .css', () => {
      const result = getMimeTypeAndMsgtype('/path/to/style.css', false);
      expect(result.mimeType).toBe('text/css');
    });

    test('should return correct mime type for .py', () => {
      const result = getMimeTypeAndMsgtype('/path/to/script.py', false);
      expect(result.mimeType).toBe('text/x-python');
    });

    test('should return correct mime type for .tar', () => {
      const result = getMimeTypeAndMsgtype('/path/to/archive.tar', false);
      expect(result.mimeType).toBe('application/x-tar');
    });
  });

  describe('getImageDimensions', () => {
    test('should return null for buffer less than 8 bytes', () => {
      const result = getImageDimensions(Buffer.from([1, 2, 3, 4]), 'png');

      expect(result).toBeNull();
    });

    test('should return dimensions for valid PNG', () => {
      const pngBuffer = Buffer.from([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x20,
      ]);

      const result = getImageDimensions(pngBuffer, 'png');

      expect(result).toEqual({ width: 16, height: 32 });
    });

    test('should return null for invalid PNG signature', () => {
      const invalidPng = Buffer.from([
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x20,
      ]);

      const result = getImageDimensions(invalidPng, 'png');

      expect(result).toBeNull();
    });

    test('should return null for non-image extension', () => {
      const result = getImageDimensions(Buffer.alloc(100), 'pdf');

      expect(result).toBeNull();
    });

    test('should handle JPEG parsing gracefully', () => {
      const jpegBuffer = Buffer.from([
        0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08,
        0x00, 0x20, 0x00, 0x10, 0x03, 0x01, 0x22, 0x00, 0x02,
      ]);

      const result = getImageDimensions(jpegBuffer, 'jpg');

      expect(result).toBeTruthy();
    });

    test('should return null when JPEG marker not found', () => {
      const invalidJpeg = Buffer.from([
        0xFF, 0xD8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);

      const result = getImageDimensions(invalidJpeg, 'jpg');

      expect(result).toBeNull();
    });

    test('should handle buffer read error gracefully', () => {
      const problematicBuffer = {
        length: 100,
        toString: () => 'PNG\r\n\x1a\n',
        readUInt32BE: () => {
          throw new Error('Read error');
        }
      };

      const result = getImageDimensions(problematicBuffer, 'png');

      expect(result).toBeNull();
    });
  });

  describe('uploadFile function', () => {
    beforeEach(() => {
      const common = require('./_common');
      common.resolveAccessToken.mockReturnValue('resolved_token');
    });

    test('should exit 1 when filePath is missing', async () => {

      await expect(uploadFile({
        filePath: null,
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: 缺少必填参数 --file']);
    });

    test('should exit 1 when roomId is missing', async () => {

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: null,
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 1');

      expect(mockConsole.errors).toContainEqual(['错误: 缺少必填参数 --room-id']);
    });

    test('should exit 1 when accessToken is missing', async () => {

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!room:example.com',
        accessToken: null,
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 1');

      expect(mockConsole.errors[0][0]).toContain('缺少 access_token');
    });

    test('should exit 5 when file does not exist', async () => {
      mockFs.existsSync.mockReturnValue(false);

      await expect(uploadFile({
        filePath: '/nonexistent.jpg',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 5');

      expect(mockConsole.errors).toContainEqual(['错误: 文件不存在 - /nonexistent.jpg']);
    });

    test('should exit 5 when file read fails', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockImplementation(() => {
        throw new Error('Read permission denied');
      });

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 5');

      expect(mockConsole.errors[0][0]).toContain('读取文件失败');
    });

    test('should exit 3 when authentication fails (401)', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });

      const authError = new Error('Unauthorized');
      authError.statusCode = 401;
      mockClient.whoami.mockRejectedValue(authError);

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!room:example.com',
        accessToken: 'bad_token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 3');

      expect(mockConsole.errors).toContainEqual(['错误: 认证失败，access_token 无效或已过期']);
    });

    test('should exit 3 when authentication fails (403)', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });

      const authError = new Error('Forbidden');
      authError.statusCode = 403;
      mockClient.whoami.mockRejectedValue(authError);

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!room:example.com',
        accessToken: 'bad_token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 3');

      expect(mockConsole.errors).toContainEqual(['错误: 认证失败，access_token 无效或已过期']);
    });

    test('should exit 2 when connection fails', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });

      const connError = new Error('Connection refused');
      connError.statusCode = 503;
      mockClient.whoami.mockRejectedValue(connError);

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 2');

      expect(mockConsole.errors[0][0]).toContain('连接 Synapse 失败');
    });

    test('should exit 4 when room does not exist (404)', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });

      const roomError = new Error('Room not found');
      roomError.statusCode = 404;
      mockClient.roomState.mockRejectedValue(roomError);

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!invalid:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors).toContainEqual(['错误: 房间不存在或无权限访问']);
    });

    test('should exit 4 when no room permission (403)', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });

      const roomError = new Error('Forbidden');
      roomError.statusCode = 403;
      mockClient.roomState.mockRejectedValue(roomError);

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!private:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors).toContainEqual(['错误: 房间不存在或无权限访问']);
    });

    test('should successfully upload image file', async () => {
      const pngBuffer = Buffer.from([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x64,
      ]);

      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(pngBuffer);
      mockFs.statSync.mockReturnValue({ size: pngBuffer.length });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);
      mockClient.uploadContent.mockResolvedValue({ content_uri: 'mxc://example.com/image' });
      mockClient.sendEvent.mockResolvedValue({ event_id: '$event1' });



      const result = await uploadFile({
        filePath: '/test/image.png',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.room_id).toBe('!room:example.com');
      expect(result.file.mime_type).toBe('image/png');
      expect(result.upload.mxc_url).toBe('mxc://example.com/image');
      expect(mockClient.sendEvent).toHaveBeenCalled();
    });

    test('should successfully upload video file', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('video content'));
      mockFs.statSync.mockReturnValue({ size: 12 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);
      mockClient.uploadContent.mockResolvedValue({ content_uri: 'mxc://example.com/video' });
      mockClient.sendEvent.mockResolvedValue({ event_id: '$event_v' });

      const result = await uploadFile({
        filePath: '/test/video.mp4',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.file.mime_type).toBe('video/mp4');
      expect(result.file.msgtype).toBe('m.video');
    });

    test('should successfully upload audio file', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('audio content'));
      mockFs.statSync.mockReturnValue({ size: 12 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);
      mockClient.uploadContent.mockResolvedValue({ content_uri: 'mxc://example.com/audio' });
      mockClient.sendEvent.mockResolvedValue({ event_id: '$event_a' });

      const result = await uploadFile({
        filePath: '/test/audio.mp3',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.file.mime_type).toBe('audio/mpeg');
      expect(result.file.msgtype).toBe('m.audio');
    });

    test('should exit 5 when statSync fails', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockImplementation(() => {
        throw new Error('Stat permission denied');
      });

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 5');

      expect(mockConsole.errors[0][0]).toContain('读取文件失败');
    });

    test('should exit 4 for other room state errors', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });

      const roomError = new Error('Internal Server Error');
      roomError.statusCode = 500;
      mockClient.roomState.mockRejectedValue(roomError);

      await expect(uploadFile({
        filePath: '/test/file.jpg',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 4');

      expect(mockConsole.errors[0][0]).toContain('验证房间失败');
    });

    test('should handle image without dimensions', async () => {
      const invalidPngBuffer = Buffer.from([
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      ]);

      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(invalidPngBuffer);
      mockFs.statSync.mockReturnValue({ size: 8 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);
      mockClient.uploadContent.mockResolvedValue({ content_uri: 'mxc://example.com/image' });
      mockClient.sendEvent.mockResolvedValue({ event_id: '$event_no_dim' });

      const result = await uploadFile({
        filePath: '/test/invalid.png',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.upload.dimensions).toBeNull();
      expect(result.file.msgtype).toBe('m.image');
    });

    test('should successfully upload file as attachment', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('file content'));
      mockFs.statSync.mockReturnValue({ size: 12 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);
      mockClient.uploadContent.mockResolvedValue({ content_uri: 'mxc://example.com/file' });
      mockClient.sendEvent.mockResolvedValue({ event_id: '$event2' });

      const result = await uploadFile({
        filePath: '/test/image.jpg',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server',
        asAttachment: true
      });

      expect(result.file.msgtype).toBe('m.file');
    });

    test('should exit 2 when upload fails', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);

      const uploadError = new Error('Upload failed');
      mockClient.uploadContent.mockRejectedValue(uploadError);

      await expect(uploadFile({
        filePath: '/test/file.pdf',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 2');

      expect(mockConsole.errors[0][0]).toContain('文件上传失败');
    });

    test('should exit 2 when send event fails', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);
      mockClient.uploadContent.mockResolvedValue({ content_uri: 'mxc://example.com/file' });

      const sendError = new Error('Send failed');
      mockClient.sendEvent.mockRejectedValue(sendError);

      await expect(uploadFile({
        filePath: '/test/file.pdf',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      })).rejects.toThrow('Process exit with code 2');

      expect(mockConsole.errors[0][0]).toContain('发送消息失败');
    });

    test('should handle uploadContent returning string directly', async () => {
      mockFs.existsSync.mockReturnValue(true);
      mockFs.readFileSync.mockReturnValue(Buffer.from('test'));
      mockFs.statSync.mockReturnValue({ size: 1000 });
      mockClient.whoami.mockResolvedValue({ user_id: '@test:example.com' });
      mockClient.roomState.mockResolvedValue([]);
      mockClient.uploadContent.mockResolvedValue('mxc://example.com/direct');
      mockClient.sendEvent.mockResolvedValue({ event_id: '$event3' });

      const result = await uploadFile({
        filePath: '/test/file.pdf',
        roomId: '!room:example.com',
        accessToken: 'token',
        homeserver: 'http://server'
      });

      expect(result.upload.mxc_url).toBe('mxc://example.com/direct');
    });
  });
});
