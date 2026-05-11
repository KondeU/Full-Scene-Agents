#!/usr/bin/env node

/**
 * obtain_access_token.js
 *
 * 通过 access_token.json 中的账号信息登录 Matrix，获取 AccessToken 并写回 JSON。
 * 聊天室辅助工具，用于获取或刷新认证令牌。
 *
 * 依赖: matrix-js-sdk
 * 用法: node tools/obtain_access_token.js [options]
 *
 * 返回码:
 *   0 - 成功
 *   1 - 参数错误
 *   2 - 登录失败（网络或服务器错误）
 *   3 - 认证失败（用户名或密码错误）
 *   4 - 配置文件错误
 */

// eslint-disable-next-line @typescript-eslint/no-require-imports
const sdk = require("matrix-js-sdk");
const fs = require("fs");
const path = require("path");

// ─── 参数解析 ───────────────────────────────────────────

function parseArgs(argv) {
  const args = {
    configFile: path.join(__dirname, "access_token.json"),
    userId: null,
    password: null,
    homeserver: null,
    deviceName: null,
    useArgs: false,
  };

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case "--file":
        if (i + 1 >= argv.length) {
          console.error("错误: --file 参数需要一个值");
          process.exit(1);
        }
        args.configFile = argv[++i];
        break;
      case "--user-id":
        if (i + 1 >= argv.length) {
          console.error("错误: --user-id 参数需要一个值");
          process.exit(1);
        }
        args.userId = argv[++i];
        args.useArgs = true;
        break;
      case "--password":
        if (i + 1 >= argv.length) {
          console.error("错误: --password 参数需要一个值");
          process.exit(1);
        }
        args.password = argv[++i];
        args.useArgs = true;
        break;
      case "--homeserver":
        if (i + 1 >= argv.length) {
          console.error("错误: --homeserver 参数需要一个值");
          process.exit(1);
        }
        args.homeserver = argv[++i];
        args.useArgs = true;
        break;
      case "--device-name":
        if (i + 1 >= argv.length) {
          console.error("错误: --device-name 参数需要一个值");
          process.exit(1);
        }
        args.deviceName = argv[++i];
        args.useArgs = true;
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
obtain_access_token.js — 通过账号密码登录 Matrix，获取 AccessToken 并写回配置文件

用法:
  node tools/obtain_access_token.js [options]

模式一：从配置文件读取（默认）
  不指定 --user-id/--password/--homeserver/--device-name 时，脚本从 access_token.json 中读取登录信息，
  获取到 AccessToken 后写回同一文件的 accessToken 字段。

模式二：通过参数指定
  通过 --user-id + --password + --homeserver + --device-name 四个参数提供登录信息。
  注意：四个参数必须同时提供，不能只给部分，否则会报错。
  获取到 AccessToken 后同样写回配置文件。

可选参数:
  --file <path>            配置文件路径 (默认: 同目录下的 access_token.json)
  --user-id <id>           Matrix 用户 ID，如 @user:example.com (与 --password、--homeserver、--device-name 必须同时提供)
  --password <password>    Matrix 用户密码 (与 --user-id、--homeserver、--device-name 必须同时提供)
  --homeserver <url>       Matrix Homeserver URL (与 --user-id、--password、--device-name 必须同时提供)
  --device-name <name>     登录设备名称 (与 --user-id、--password、--homeserver 必须同时提供)
  -h, --help               显示帮助信息

注意:
  如果通过参数指定登录信息，--user-id、--password、--homeserver、--device-name 四个参数必须同时提供，
  不允许部分使用参数、部分使用配置文件，以避免信息混乱。

示例:
  node tools/obtain_access_token.js
  node tools/obtain_access_token.js --file /path/to/access_token.json
  node tools/obtain_access_token.js --user-id "@laptop:sup.kdyx.net" --password "123456" --homeserver "http://140.143.96.124:8888" --device-name "Laptop"
`);
}

// ─── 核心逻辑 ───────────────────────────────────────────

/**
 * 读取配置文件，解析参数，登录获取 AccessToken 并写回
 */
async function obtainAccessToken(args) {
  // 读取配置文件
  let config;
  try {
    if (!fs.existsSync(args.configFile)) {
      console.error(`错误: 配置文件不存在 - ${args.configFile}`);
      process.exit(4);
    }
    config = JSON.parse(fs.readFileSync(args.configFile, "utf8"));
  } catch (err) {
    console.error(`错误: 读取配置文件失败 - ${err.message}`);
    process.exit(4);
  }

  // 验证配置文件基本结构
  if (!config.userId || !config.password || !config.homeserver) {
    console.error("错误: 配置文件缺少必要字段 (userId, password, homeserver)");
    process.exit(4);
  }

  // 参数模式校验：如果通过参数指定，则三个必填参数必须同时提供
  let userId, password, homeserver, deviceName;

  if (args.useArgs) {
    if (!args.userId || !args.password || !args.homeserver) {
      console.error("错误: 使用参数模式时，--user-id、--password、--homeserver 必须同时提供，不允许部分指定");
      process.exit(1);
    }
    userId = args.userId;
    password = args.password;
    homeserver = args.homeserver;
    deviceName = args.deviceName || config.deviceName || null;
  } else {
    // 从配置文件读取
    userId = config.userId;
    password = config.password;
    homeserver = config.homeserver;
    deviceName = args.deviceName || config.deviceName || null;
  }

  // 移除 homeserver 末尾的斜杠
  homeserver = homeserver.replace(/\/+$/, "");

  console.log(`正在登录: ${userId} @ ${homeserver} ...`);

  // 登录获取 AccessToken
  let accessToken;
  try {
    const client = sdk.createClient({ baseUrl: homeserver });
    const loginResponse = await client.login("m.login.password", {
      user: userId,
      password: password,
      initial_device_display_name: deviceName || undefined,
    });
    accessToken = loginResponse.access_token;
  } catch (err) {
    if (err.statusCode === 401 || err.statusCode === 403) {
      console.error("错误: 认证失败，用户名或密码错误");
      process.exit(3);
    }
    console.error(`错误: 登录失败 - ${err.message}`);
    process.exit(2);
  }

  if (!accessToken) {
    console.error("错误: 登录成功但未获取到 access_token");
    process.exit(2);
  }

  // 写回配置文件
  config.accessToken = accessToken;
  try {
    fs.writeFileSync(args.configFile, JSON.stringify(config, null, 4) + "\n", "utf8");
  } catch (err) {
    console.error(`错误: 写入配置文件失败 - ${err.message}`);
    process.exit(4);
  }

  // 输出结果
  const result = {
    timestamp: new Date().toISOString(),
    user_id: userId,
    homeserver: homeserver,
    access_token: accessToken,
    config_file: args.configFile,
    mode: args.useArgs ? "args" : "config",
  };

  console.log(JSON.stringify(result, null, 2));
  return result;
}

// ─── 入口 ───────────────────────────────────────────────

function main() {
  const args = parseArgs(process.argv);
  obtainAccessToken(args).catch((err) => {
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
  obtainAccessToken,
  main,
};
