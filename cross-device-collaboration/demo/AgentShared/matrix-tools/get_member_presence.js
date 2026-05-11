#!/usr/bin/env node

/**
 * get_member_presence.js
 *
 * 获取 Matrix 聊天室内所有成员的在线状态。
 * 聊天室核心工具，用于感知房间内设备的在线情况。
 *
 * 依赖: matrix-js-sdk
 * 用法: node tools/get_member_presence.js --room-id <room_id> [--homeserver <url>] [--access-token <token>]
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
  };

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case "--room-id":
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
get_member_presence.js — 获取 Matrix 聊天室内所有成员的在线状态

用法:
  node tools/get_member_presence.js --room-id <room_id> [options]

必填参数:
  --room-id <room_id>       Matrix 房间 ID (如 !xxx:sup.kdyx.net)

可选参数:
  --homeserver <url>        Synapse Homeserver URL (默认: http://140.143.96.124:8888)
  --access-token <token>    管理员访问令牌 (优先级: 参数 > access_token.json > 环境变量)
  -h, --help                显示帮助信息

AccessToken 优先级:
  --access-token 参数 > access_token.json > 环境变量 MATRIX_ACCESS_TOKEN

示例:
  node tools/get_member_presence.js --room-id "!xxx:sup.kdyx.net"
  MATRIX_ACCESS_TOKEN=syt_xxx node tools/get_member_presence.js --room-id "!xxx:sup.kdyx.net"
`);
}

// ─── 核心逻辑 ───────────────────────────────────────────

/**
 * 初始化 Matrix Client 并获取房间成员在线状态
 */
async function getMemberPresence(args) {
  // 参数校验
  if (!args.roomId) {
    console.error("错误: 缺少必填参数 --room-id");
    process.exit(1);
  }
  if (!args.accessToken) {
    console.error("错误: 缺少 access_token，请通过 --access-token 参数、access_token.json 或 MATRIX_ACCESS_TOKEN 环境变量提供");
    process.exit(1);
  }

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

  // 获取房间成员列表
  let members = [];
  try {
    const roomState = await client.roomState(args.roomId);
    members = roomState
      .filter((event) => event.type === "m.room.member" && event.content.membership === "join")
      .map((event) => ({
        mxid: event.state_key,
        display_name: event.content.displayname || event.state_key,
        avatar_url: event.content.avatar_url || null,
      }));
  } catch (err) {
    if (err.statusCode === 403) {
      console.error("错误: 房间不存在或无权限访问");
      process.exit(4);
    }
    if (err.statusCode === 404) {
      console.error("错误: 房间不存在");
      process.exit(4);
    }
    console.error(`错误: 获取房间成员失败 - ${err.message}`);
    process.exit(4);
  }

  if (!members || members.length === 0) {
    console.error("警告: 房间内无成员");
  }

  // 逐个获取成员 Presence
  const presenceResults = [];
  for (const member of members) {
    // 跳过自身（不需要查自己的在线状态）
    if (member.mxid === userId) {
      continue;
    }

    let presence = "offline";
    let lastActiveAgo = null;

    try {
      // 使用 /_matrix/client/v3/presence/{userId}/status 获取在线状态
      const presenceData = await client.getPresence(member.mxid);
      presence = presenceData.presence || "offline";
      lastActiveAgo = presenceData.last_active_ago || null;
    } catch (err) {
      // Presence 获取失败时默认为 offline，不中断流程
      presence = "offline";
      lastActiveAgo = null;
    }

    presenceResults.push({
      mxid: member.mxid,
      display_name: member.display_name,
      presence: presence,
      last_active_ago: lastActiveAgo,
    });
  }

  // 汇总统计
  const summary = {
    total: presenceResults.length,
    online: presenceResults.filter((m) => m.presence === "online").length,
    unavailable: presenceResults.filter((m) => m.presence === "unavailable").length,
    offline: presenceResults.filter((m) => m.presence === "offline").length,
  };

  // 输出结果
  const result = {
    room_id: args.roomId,
    timestamp: new Date().toISOString(),
    queried_by: userId,
    members: presenceResults,
    summary: summary,
  };

  console.log(JSON.stringify(result, null, 2));
  return result;
}

// ─── 入口 ───────────────────────────────────────────────

function main() {
  const args = parseArgs(process.argv);
  args.accessToken = resolveAccessToken(args.accessToken);
  getMemberPresence(args).catch((err) => {
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
  getMemberPresence,
  main,
};
