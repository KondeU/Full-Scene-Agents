#!/usr/bin/env node

/**
 * upload_file.js
 *
 * 将本地文件上传到 Matrix 聊天室，并发送为文件/图片/视频/音频消息。
 * 聊天室核心工具，用于在需要时分享文件和媒体资源。
 *
 * 依赖: matrix-js-sdk
 * 用法: node tools/upload_file.js --file <path> --room-id <room_id> [options]
 *
 * 返回码:
 *   0 - 成功
 *   1 - 参数错误
 *   2 - 连接 Synapse 失败
 *   3 - 认证失败
 *   4 - 房间不存在或无权限
 *   5 - 文件错误（不存在、无法读取等）
 */

// eslint-disable-next-line @typescript-eslint/no-require-imports
const sdk = require("matrix-js-sdk");
const fs = require("fs");
const path = require("path");
const { resolveAccessToken } = require("./_common");

// ─── 参数解析 ───────────────────────────────────────────

function parseArgs(argv) {
  const args = {
    filePath: null,
    roomId: null,
    homeserver: "http://140.143.96.124:8888",
    accessToken: null,
    asAttachment: false,
  };

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case "--file":
      case "-f":
        if (i + 1 >= argv.length) {
          console.error("错误: --file 参数需要一个值");
          process.exit(1);
        }
        args.filePath = argv[++i];
        break;
      case "--room-id":
      case "-r":
        if (i + 1 >= argv.length) {
          console.error("错误: --room-id 参数需要一个值");
          process.exit(1);
        }
        args.roomId = argv[++i];
        break;
      case "--homeserver":
        if (i + 1 >= argv.length) {
          console.error("错误: --homeserver 参数需要一个值");
          process.exit(1);
        }
        args.homeserver = argv[++i];
        break;
      case "--access-token":
        if (i + 1 >= argv.length) {
          console.error("错误: --access-token 参数需要一个值");
          process.exit(1);
        }
        args.accessToken = argv[++i];
        break;
      case "--as-attachment":
        args.asAttachment = true;
        break;
      case "--help":
      case "-h":
        printHelp();
        process.exit(0);
      default:
        console.error(`未知参数: ${argv[i]}`);
        process.exit(1);
    }
  }

  return args;
}

function printHelp() {
  console.log(`
upload_file.js — 将本地文件上传到 Matrix 聊天室

用法:
  node tools/upload_file.js --file <path> --room-id <room_id> [options]

必填参数:
  --file, -f <path>        要上传的本地文件路径
  --room-id, -r <room_id>  Matrix 房间 ID (如 !xxx:sup.kdyx.net)

可选参数:
  --homeserver <url>       Synapse Homeserver URL (默认: http://140.143.96.124:8888)
  --access-token <token>   管理员访问令牌 (优先级: 参数 > access_token.json > 环境变量)
  --as-attachment          强制作为普通文件发送，不自动识别为图片/视频/音频
  -h, --help               显示帮助信息

AccessToken 优先级:
  --access-token 参数 > access_token.json > 环境变量 MATRIX_ACCESS_TOKEN

支持的文件类型:
  图片: .jpg, .jpeg, .png, .gif, .webp, .bmp, .svg, .ico, .tiff
  视频: .mp4, .webm, .mov, .avi, .mkv, .flv
  音频: .mp3, .wav, .ogg, .flac, .aac, .m4a, .wma
  文档: .pdf, .doc, .docx, .xls, .xlsx, .ppt, .pptx, .txt, .md, .csv, .rtf
  代码: .json, .xml, .yaml, .sql, .html, .css, .js, .ts, .py, .sh
  压缩: .zip, .rar, .7z, .tar, .gz, .bz2
  其他: 未识别的类型自动作为通用二进制文件 (application/octet-stream) 上传

示例:
  node tools/upload_file.js --file ./image.jpg --room-id "!xxx:sup.kdyx.net"
  MATRIX_ACCESS_TOKEN=syt_xxx node tools/upload_file.js -f ./report.pdf -r "!xxx:sup.kdyx.net"
`);
}

// ─── 辅助函数 ───────────────────────────────────────────

function getMimeTypeAndMsgtype(filePath, forceAttachment) {
  const ext = path.extname(filePath).toLowerCase();
  const mimeTypes = {
    // 图片
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
    ".tiff": "image/tiff",
    ".tif": "image/tiff",
    // 视频
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".mov": "video/quicktime",
    ".avi": "video/x-msvideo",
    ".mkv": "video/x-matroska",
    ".flv": "video/x-flv",
    // 音频
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
    ".ogg": "audio/ogg",
    ".flac": "audio/flac",
    ".aac": "audio/aac",
    ".m4a": "audio/mp4",
    ".wma": "audio/x-ms-wma",
    // 文档
    ".pdf": "application/pdf",
    ".doc": "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xls": "application/vnd.ms-excel",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".ppt": "application/vnd.ms-powerpoint",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".txt": "text/plain",
    ".md": "text/markdown",
    ".csv": "text/csv",
    ".rtf": "application/rtf",
    // 数据/代码
    ".json": "application/json",
    ".xml": "application/xml",
    ".yaml": "application/x-yaml",
    ".yml": "application/x-yaml",
    ".sql": "application/sql",
    ".html": "text/html",
    ".htm": "text/html",
    ".css": "text/css",
    ".js": "text/javascript",
    ".ts": "application/typescript",
    ".py": "text/x-python",
    ".sh": "application/x-sh",
    // 压缩包
    ".zip": "application/zip",
    ".rar": "application/vnd.rar",
    ".7z": "application/x-7z-compressed",
    ".tar": "application/x-tar",
    ".gz": "application/gzip",
    ".bz2": "application/x-bzip2",
  };

  const mimeType = mimeTypes[ext] || "application/octet-stream";
  let msgtype = "m.file";

  if (!forceAttachment) {
    if (mimeType.startsWith("image/")) {
      msgtype = "m.image";
    } else if (mimeType.startsWith("video/")) {
      msgtype = "m.video";
    } else if (mimeType.startsWith("audio/")) {
      msgtype = "m.audio";
    }
  }

  return { mimeType, msgtype };
}

function getImageDimensions(buffer, ext) {
  try {
    if (buffer.length < 8) return null;

    if (ext === "png") {
      if (buffer.toString("ascii", 1, 8) === "PNG\r\n\x1a\n") {
        return {
          width: buffer.readUInt32BE(16),
          height: buffer.readUInt32BE(20),
        };
      }
    }

    if (ext === "jpg" || ext === "jpeg") {
      let offset = 2;
      while (offset < buffer.length - 4) {
        if (buffer[offset] !== 0xFF) {
          offset++;
          continue;
        }
        const marker = buffer[offset + 1];
        if (
          (marker >= 0xC0 && marker <= 0xC3) ||
          (marker >= 0xC5 && marker <= 0xC7) ||
          (marker >= 0xC9 && marker <= 0xCB) ||
          (marker >= 0xCD && marker <= 0xCF)
        ) {
          return {
            width: buffer.readUInt16BE(offset + 7),
            height: buffer.readUInt16BE(offset + 5),
          };
        }
        if ((marker >= 0xD0 && marker <= 0xD7) || marker === 0xD8 || marker === 0xD9) {
          offset += 2;
        } else {
          offset += 2;
          if (offset + 2 <= buffer.length) {
            offset += buffer.readUInt16BE(offset);
          }
        }
      }
    }
  } catch (e) {
    // 忽略尺寸检测错误
    console.error("错误: 图片尺寸检测错误，对上传任务可能不造成影响，继续执行。");
  }
  return null;
}

// ─── 核心逻辑 ───────────────────────────────────────────

/**
 * 初始化 Matrix Client 并上传文件
 */
async function uploadFile(args) {
  // 参数校验
  if (!args.filePath) {
    console.error("错误: 缺少必填参数 --file");
    process.exit(1);
  }
  if (!args.roomId) {
    console.error("错误: 缺少必填参数 --room-id");
    process.exit(1);
  }
  if (!args.accessToken) {
    console.error("错误: 缺少 access_token，请通过 --access-token 参数、access_token.json 或 MATRIX_ACCESS_TOKEN 环境变量提供");
    process.exit(1);
  }

  // 文件校验
  let fileBuffer;
  let fileStats;
  try {
    if (!fs.existsSync(args.filePath)) {
      console.error(`错误: 文件不存在 - ${args.filePath}`);
      process.exit(5);
    }
    fileBuffer = fs.readFileSync(args.filePath);
    fileStats = fs.statSync(args.filePath);
  } catch (err) {
    console.error(`错误: 读取文件失败 - ${err.message}`);
    process.exit(5);
  }

  const fileName = path.basename(args.filePath);
  const fileSize = fileStats.size;

  // 创建 Matrix Client
  const client = sdk.createClient({
    baseUrl: args.homeserver,
    accessToken: args.accessToken,
  });

  // 验证连接 & 认证
  let userId;
  try {
    const whoami = await client.whoami();
    userId = whoami.user_id;
  } catch (err) {
    if (err.statusCode === 401 || err.statusCode === 403) {
      console.error("错误: 认证失败，access_token 无效或已过期");
      process.exit(3);
    }
    console.error(`错误: 连接 Synapse 失败 - ${err.message}`);
    process.exit(2);
  }

  // 验证房间是否存在（尝试获取房间状态）
  try {
    await client.roomState(args.roomId);
  } catch (err) {
    if (err.statusCode === 403 || err.statusCode === 404) {
      console.error("错误: 房间不存在或无权限访问");
      process.exit(4);
    }
    console.error(`错误: 验证房间失败 - ${err.message}`);
    process.exit(4);
  }

  // 确定文件类型
  const { mimeType, msgtype } = getMimeTypeAndMsgtype(args.filePath, args.asAttachment);

  // 上传文件到 Matrix 媒体库
  let mxcUrl;
  try {
    const uploadResponse = await client.uploadContent(fileBuffer, {
      name: fileName,
      type: mimeType,
    });
    mxcUrl = typeof uploadResponse === "string" ? uploadResponse : uploadResponse.content_uri;
  } catch (err) {
    console.error(`错误: 文件上传失败 - ${err.message}`);
    process.exit(2);
  }

  // 检测图片尺寸（如果是图片）
  let dimensions = null;
  if (msgtype === "m.image") {
    const ext = path.extname(args.filePath).toLowerCase().replace(".", "");
    dimensions = getImageDimensions(fileBuffer, ext);
  }

  // 构建消息内容
  const info = {
    mimetype: mimeType,
    size: fileSize,
  };

  if (dimensions) {
    info.w = dimensions.width;
    info.h = dimensions.height;
  }

  const content = {
    msgtype: msgtype,
    body: fileName,
    url: mxcUrl,
    info: info,
  };

  // 发送消息到房间
  let eventId;
  try {
    const eventResponse = await client.sendEvent(args.roomId, "m.room.message", content);
    eventId = eventResponse.event_id;
  } catch (err) {
    console.error(`错误: 发送消息失败 - ${err.message}`);
    process.exit(2);
  }

  // 输出结果
  const result = {
    room_id: args.roomId,
    timestamp: new Date().toISOString(),
    uploaded_by: userId,
    file: {
      name: fileName,
      path: args.filePath,
      size: fileSize,
      mime_type: mimeType,
      msgtype: msgtype,
    },
    upload: {
      mxc_url: mxcUrl,
      event_id: eventId,
      dimensions: dimensions,
    },
  };

  console.log(JSON.stringify(result, null, 2));
  return result;
}

// ─── 入口 ───────────────────────────────────────────────

function main() {
  const args = parseArgs(process.argv);
  args.accessToken = resolveAccessToken(args.accessToken);
  uploadFile(args).catch((err) => {
    console.error(`未预期的错误: ${err.message}`);
    process.exit(2);
  });
}

if (require.main === module) {
  main();
}

module.exports = {
  parseArgs,
  printHelp,
  getMimeTypeAndMsgtype,
  getImageDimensions,
  uploadFile,
  main,
};
