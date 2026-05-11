#!/usr/bin/env node

/**
 * install_matrix-js-sdk.js
 *
 * 自动安装 matrix-js-sdk 依赖包。
 * 聊天室辅助工具，用于快速配置开发/运行环境。
 *
 * 用法: node tools/install_matrix-js-sdk.js [options]
 *
 * 返回码:
 *   0 - 成功（已安装或新安装成功）
 *   1 - 参数错误
 *   2 - 安装失败
 *   3 - 包管理器不可用
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// ─── 参数解析 ───────────────────────────────────────────

function parseArgs(argv) {
  const args = {
    version: null,
    packageManager: null,
    global: false,
    saveDev: false,
    checkOnly: false,
  };

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case "--version":
      case "-v":
        if (i + 1 >= argv.length) {
          console.error("错误: --version 参数需要一个值");
          process.exit(1);
        }
        args.version = argv[++i];
        break;
      case "--package-manager":
      case "-p":
        if (i + 1 >= argv.length) {
          console.error("错误: --package-manager 参数需要一个值");
          process.exit(1);
        }
        const pm = argv[++i].toLowerCase();
        if (!["npm", "yarn", "pnpm"].includes(pm)) {
          console.error("错误: 包管理器必须是 npm, yarn 或 pnpm");
          process.exit(1);
        }
        args.packageManager = pm;
        break;
      case "--global":
      case "-g":
        args.global = true;
        break;
      case "--save-dev":
      case "-D":
        args.saveDev = true;
        break;
      case "--check-only":
      case "-c":
        args.checkOnly = true;
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
install_matrix-js-sdk.js — 自动安装 matrix-js-sdk 依赖包

用法:
  node tools/install_matrix-js-sdk.js [options]

可选参数:
  --version, -v <version>  指定安装的版本 (如: latest, 32.0.0, ^32.0.0)
  --package-manager, -p <pm>  指定包管理器: npm, yarn, pnpm (自动检测)
  --global, -g             全局安装
  --save-dev, -D           保存为开发依赖 (devDependencies)
  --check-only, -c         仅检查是否已安装，不实际安装
  -h, --help               显示帮助信息

示例:
  node tools/install_matrix-js-sdk.js
  node tools/install_matrix-js-sdk.js --version 32.0.0
  node tools/install_matrix-js-sdk.js --package-manager pnpm --save-dev
  node tools/install_matrix-js-sdk.js --check-only
`);
}

// ─── 辅助函数 ───────────────────────────────────────────

function detectPackageManager() {
  const cwd = process.cwd();

  if (fs.existsSync(path.join(cwd, "pnpm-lock.yaml"))) {
    return "pnpm";
  }
  if (fs.existsSync(path.join(cwd, "yarn.lock"))) {
    return "yarn";
  }
  if (fs.existsSync(path.join(cwd, "package-lock.json"))) {
    return "npm";
  }

  try {
    execSync("pnpm --version", { stdio: "ignore" });
    return "pnpm";
  } catch (e) {
    try {
      execSync("yarn --version", { stdio: "ignore" });
      return "yarn";
    } catch (e2) {
      try {
        execSync("npm --version", { stdio: "ignore" });
        return "npm";
      } catch (e3) {
        return null;
      }
    }
  }
}

function checkInstalled(global = false) {
  try {
    if (global) {
      const npmRoot = execSync("npm root -g", { encoding: "utf8" }).trim();
      require.resolve(path.join(npmRoot, "matrix-js-sdk"));
      return true;
    } else {
      require.resolve("matrix-js-sdk");
      return true;
    }
  } catch (e) {
    return false;
  }
}

function getInstalledVersion(global = false) {
  try {
    let pkgPath;
    if (global) {
      const npmRoot = execSync("npm root -g", { encoding: "utf8" }).trim();
      pkgPath = path.join(npmRoot, "matrix-js-sdk", "package.json");
    } else {
      pkgPath = require.resolve("matrix-js-sdk/package.json");
    }
    const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
    return pkg.version;
  } catch (e) {
    return null;
  }
}

function buildInstallCommand(packageManager, version, global, saveDev) {
  const pkgName = version ? `matrix-js-sdk@${version}` : "matrix-js-sdk";
  let cmd;

  switch (packageManager) {
    case "npm":
      cmd = ["npm", "install"];
      if (global) cmd.push("-g");
      if (saveDev) cmd.push("--save-dev");
      cmd.push(pkgName);
      break;
    case "yarn":
      if (global) {
        cmd = ["yarn", "global", "add"];
      } else {
        cmd = ["yarn", "add"];
        if (saveDev) cmd.push("--dev");
      }
      cmd.push(pkgName);
      break;
    case "pnpm":
      cmd = ["pnpm", "add"];
      if (global) cmd.push("-g");
      if (saveDev) cmd.push("-D");
      cmd.push(pkgName);
      break;
    default:
      throw new Error("未知的包管理器");
  }

  return cmd;
}

// ─── 核心逻辑 ───────────────────────────────────────────

function installMatrixJsSdk(args) {
  const isInstalled = checkInstalled(args.global);
  const installedVersion = getInstalledVersion(args.global);

  if (args.checkOnly) {
    const result = {
      timestamp: new Date().toISOString(),
      installed: isInstalled,
      version: installedVersion,
      global: args.global,
    };
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
  }

  if (isInstalled) {
    console.log(`matrix-js-sdk 已安装 (版本: ${installedVersion})`);
    const result = {
      timestamp: new Date().toISOString(),
      action: "already_installed",
      installed: true,
      version: installedVersion,
      global: args.global,
    };
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
  }

  if (args.global && args.saveDev) {
    console.warn("警告: --save-dev 在全局安装模式下无效，将被忽略");
    args.saveDev = false;
  }

  const packageManager = args.packageManager || detectPackageManager();
  if (!packageManager) {
    console.error("错误: 未找到可用的包管理器 (npm/yarn/pnpm)");
    process.exit(3);
  }

  console.log(`使用 ${packageManager} 安装 matrix-js-sdk...`);

  const cmd = buildInstallCommand(packageManager, args.version, args.global, args.saveDev);

  try {
    execSync(cmd.join(" "), { stdio: "inherit" });
  } catch (err) {
    console.error(`错误: 安装失败 - ${err.message}`);
    process.exit(2);
  }

  const newVersion = getInstalledVersion(args.global);

  const result = {
    timestamp: new Date().toISOString(),
    action: "installed",
    package_manager: packageManager,
    installed: true,
    version: newVersion,
    global: args.global,
    saved_as_dev: args.saveDev,
  };

  console.log(JSON.stringify(result, null, 2));
  return result;
}

// ─── 入口 ───────────────────────────────────────────────

function main() {
  try {
    const args = parseArgs(process.argv);
    installMatrixJsSdk(args);
  } catch (err) {
    console.error(`未预期的错误: ${err.message}`);
    process.exit(2);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  parseArgs,
  printHelp,
  detectPackageManager,
  checkInstalled,
  getInstalledVersion,
  buildInstallCommand,
  installMatrixJsSdk,
  main,
};
