#!/usr/bin/env node

/**
 * _common.js
 *
 * matrix-tools 公共模块，提供跨脚本复用的工具函数。
 * 被 get_member_presence.js / upload_file.js / get_chat_history.js 引用。
 */

const fs = require("fs");
const path = require("path");

/**
 * 按优先级解析 AccessToken：
 *   1. 用户通过 --access-token 参数指定的值
 *   2. access_token.json 中的 accessToken 字段
 *   3. 环境变量 MATRIX_ACCESS_TOKEN
 *
 * @param {string|null} argToken  通过命令行参数传入的 token
 * @returns {string|null}
 */
function resolveAccessToken(argToken) {
  if (argToken && typeof argToken === "string" && argToken.trim()) {
    return argToken.trim();
  }
  try {
    const configFile = path.join(__dirname, "access_token.json");
    if (fs.existsSync(configFile)) {
      const config = JSON.parse(fs.readFileSync(configFile, "utf8"));
      const token = config.accessToken;
      if (token && typeof token === "string" && token.trim()) {
        return token.trim();
      }
    }
  } catch (e) { /* 忽略读取错误 */ }
  const envToken = process.env.MATRIX_ACCESS_TOKEN;
  if (envToken && typeof envToken === "string" && envToken.trim()) {
    return envToken.trim();
  }
  return null;
}

module.exports = { resolveAccessToken };
