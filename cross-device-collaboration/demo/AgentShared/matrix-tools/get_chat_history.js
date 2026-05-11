#!/usr/bin/env node

/**
 * get_chat_history.js
 *
 * 获取 Matrix 聊天室的消息历史记录。
 * 聊天室核心工具，用于回顾对话历史和上下文。
 *
 * 依赖: matrix-js-sdk
 * 用法: node tools/get_chat_history.js --room-id <room_id> [options]
 *
 * 返回码:
 *   0 - 成功
 *   1 - 参数错误
 *   2 - 连接 Synapse 失败
 *   3 - 认证失败
 *   4 - 房间不存在或无权限
 */

// eslint-disable-next-line @typescript-eslint/no-require-imports
const sdk = require("matrix-js-sdk");
const { resolveAccessToken } = require("./_common");

// ─── 参数解析 ───────────────────────────────────────────

function parseArgs(argv) {
  const args = {
    roomId: null,
    homeserver: "http://140.143.96.124:8888",
    accessToken: null,
    limit: 50,
    from: null,
    direction: "b",
    onlyText: false,
  };

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
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
      case "--limit":
      case "-n":
        if (i + 1 >= argv.length) {
          console.error("错误: --limit 参数需要一个值");
          process.exit(1);
        }
        args.limit = parseInt(argv[++i], 10);
        if (isNaN(args.limit) || args.limit < 1) {
          console.error("错误: --limit 参数必须是正整数");
          process.exit(1);
        }
        break;
      case "--from":
        if (i + 1 >= argv.length) {
          console.error("错误: --from 参数需要一个值");
          process.exit(1);
        }
        args.from = argv[++i];
        break;
      case "--direction":
      case "-d":
        if (i + 1 >= argv.length) {
          console.error("错误: --direction 参数需要一个值");
          process.exit(1);
        }
        const dir = argv[++i];
        if (dir !== "b" && dir !== "f") {
          console.error("错误: --direction 参数必须是 'b' (backward) 或 'f' (forward)");
          process.exit(1);
        }
        args.direction = dir;
        break;
      case "--only-text":
        args.onlyText = true;
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
get_chat_history.js — 获取 Matrix 聊天室的消息历史记录

用法:
  node tools/get_chat_history.js --room-id <room_id> [options]

必填参数:
  --room-id, -r <room_id>  Matrix 房间 ID (如 !xxx:sup.kdyx.net)

可选参数:
  --homeserver <url>       Synapse Homeserver URL (默认: http://140.143.96.124:8888)
  --access-token <token>   管理员访问令牌 (优先级: 参数 > access_token.json > 环境变量)
  --limit, -n <number>     获取消息数量 (默认: 50, 最大: 1000)
  --from <token>           分页起始 token，从指定位置开始获取
  --direction, -d <dir>    获取方向: 'b'=向后(旧消息), 'f'=向前(新消息) (默认: b)
  --only-text              只返回文本消息，过滤其他消息类型
  -h, --help               显示帮助信息

AccessToken 优先级:
  --access-token 参数 > access_token.json > 环境变量 MATRIX_ACCESS_TOKEN

示例:
  node tools/get_chat_history.js --room-id "!xxx:sup.kdyx.net"
  node tools/get_chat_history.js -r "!xxx:sup.kdyx.net" --limit 100 --only-text
  MATRIX_ACCESS_TOKEN=syt_xxx node tools/get_chat_history.js -r "!xxx:sup.kdyx.net" -n 20
`);
}

// ─── 辅助函数 ───────────────────────────────────────────

function formatMessage(event, userId) {
  const content = event.content || {};
  const result = {
    event_id: event.event_id,
    type: event.type,
    sender: event.sender,
    timestamp: new Date(event.origin_server_ts).toISOString(),
    origin_server_ts: event.origin_server_ts,
    is_own: event.sender === userId,
  };

  if (event.type === "m.room.message") {
    result.msgtype = content.msgtype;
    result.body = content.body || "";

    if (content.msgtype === "m.text" || content.msgtype === "m.notice") {
      if (content.format === "org.matrix.custom.html" && content.formatted_body) {
        result.formatted_body = content.formatted_body;
      }
    } else if (content.msgtype === "m.image" || content.msgtype === "m.file" ||
               content.msgtype === "m.video" || content.msgtype === "m.audio") {
      result.url = content.url;
      if (content.info) {
        result.info = {
          mimetype: content.info.mimetype,
          size: content.info.size,
          w: content.info.w,
          h: content.info.h,
        };
      }
    }
  } else if (event.type === "m.room.member") {
    result.membership = content.membership;
    result.displayname = content.displayname;
  } else if (event.type === "m.room.name") {
    result.name = content.name;
  } else if (event.type === "m.room.topic") {
    result.topic = content.topic;
  }

  return result;
}

// ─── 核心逻辑 ───────────────────────────────────────────

/**
 * 初始化 Matrix Client 并获取聊天历史
 */
async function getChatHistory(args) {
  // 参数校验
  if (!args.roomId) {
    console.error("错误: 缺少必填参数 --room-id");
    process.exit(1);
  }
  if (!args.accessToken) {
    console.error("错误: 缺少 access_token，请通过 --access-token 参数、access_token.json 或 MATRIX_ACCESS_TOKEN 环境变量提供");
    process.exit(1);
  }

  // 限制最大消息数量
  const limit = Math.min(args.limit, 1000);

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

  // 获取房间消息历史
  let messages;
  try {
    messages = await client.createMessagesRequest(
      args.roomId,
      args.from,
      limit,
      args.direction,
    );
  } catch (err) {
    if (err.statusCode === 403 || err.statusCode === 404) {
      console.error("错误: 房间不存在或无权限访问");
      process.exit(4);
    }
    console.error(`错误: 获取聊天历史失败 - ${err.message}`);
    process.exit(4);
  }

  // 格式化消息
  const formattedMessages = (messages.chunk || []).map(event => formatMessage(event, userId));

  // 过滤消息类型（如果启用）
  const filteredMessages = args.onlyText
    ? formattedMessages.filter(msg =>
        msg.type === "m.room.message" &&
        (msg.msgtype === "m.text" || msg.msgtype === "m.notice")
      )
    : formattedMessages;

  // 统计信息
  const stats = {
    total: formattedMessages.length,
    filtered: filteredMessages.length,
    by_type: {},
    by_sender: {},
  };

  formattedMessages.forEach(msg => {
    stats.by_type[msg.type] = (stats.by_type[msg.type] || 0) + 1;
    if (msg.sender) {
      stats.by_sender[msg.sender] = (stats.by_sender[msg.sender] || 0) + 1;
    }
  });

  // 输出结果
  const result = {
    room_id: args.roomId,
    timestamp: new Date().toISOString(),
    queried_by: userId,
    pagination: {
      start: messages.start,
      end: messages.end,
      has_next: !!messages.end,
    },
    query: {
      limit: limit,
      direction: args.direction,
      only_text: args.onlyText,
    },
    stats: stats,
    messages: filteredMessages,
  };

  console.log(JSON.stringify(result, null, 2));
  return result;
}

// ─── 入口 ───────────────────────────────────────────────

function main() {
  const args = parseArgs(process.argv);
  args.accessToken = resolveAccessToken(args.accessToken);
  getChatHistory(args).catch((err) => {
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
  formatMessage,
  getChatHistory,
  main,
};
