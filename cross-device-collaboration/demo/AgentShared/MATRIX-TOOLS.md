# Matrix 聊天室工具集

跨设备协同技能的工具包，用于与 Matrix 聊天服务器交互。路径：`matrix-tools/`

所有脚本使用 CommonJS，输出 JSON，默认 homeserver 为 `http://140.143.96.124:8888`。

## AccessToken 优先级

聊天室的操作需要 AccessToken，脚本会按以下优先级获取：

`调用脚本时指定的 --access-token 参数` > `access_token.json` > `环境变量 MATRIX_ACCESS_TOKEN`

其中 `access_token.json` 与脚本同目录，可通过 `obtain_access_token.js` 自动填充。

若存在可用的 `access_token.json` 文件，直接方便地使用它，不要每次操作都重新去获取一遍 AccessToken。

---

## obtain_access_token.js — 获取 AccessToken

通过账号密码登录 Matrix，将获取到的 AccessToken 写回 `access_token.json`。

```bash
# 默认从 access_token.json 读取账号信息
node matrix-tools/obtain_access_token.js

# 通过参数指定（四个参数必须同时提供，不允许部分混用）
node matrix-tools/obtain_access_token.js --file <config.json> --user-id <id> --password <pwd> --homeserver <url> --device-name <name>
```

参数：

| 参数              | 说明                                         |
| ----------------- | -------------------------------------------- |
| `--file`        | 配置文件路径（默认同目录 access_token.json） |
| `--user-id`     | Matrix 用户 ID，如 `@user:sup.kdyx.net`    |
| `--password`    | 用户密码                                     |
| `--homeserver`  | Homeserver URL                               |
| `--device-name` | 登录设备名称                                 |

---

## get_member_presence.js — 获取成员在线状态

```bash
node matrix-tools/get_member_presence.js --room-id <room_id> [--homeserver <url>] [--access-token <token>]
```

返回房间内除自身外的所有已加入成员的在线状态（online / unavailable / offline）。

---

## upload_file.js — 上传文件到房间

```bash
node matrix-tools/upload_file.js --file <path> --room-id <room_id> [--homeserver <url>] [--access-token <token>] [--as-attachment]
```

| 参数                | 说明                                                 |
| ------------------- | ---------------------------------------------------- |
| `--file, -f`      | 本地文件路径（必填）                                 |
| `--room-id, -r`   | 房间 ID（必填）                                      |
| `--as-attachment` | 强制作为 `m.file` 发送，不自动识别为图片/视频/音频 |

支持类型：图片（jpg/png/gif/webp/svg/bmp/tiff）、视频（mp4/webm/mov/avi/mkv）、音频（mp3/wav/ogg/flac/aac/m4a）、文档（pdf/doc/xls/ppt/txt/md/csv）、代码（json/xml/yaml/sql/html/css/js/py）、压缩包（zip/rar/7z/tar/gz）。未识别类型自动作为 `application/octet-stream` 上传。

---

## get_chat_history.js — 获取聊天历史

```bash
node matrix-tools/get_chat_history.js --room-id <room_id> [--homeserver <url>] [--access-token <token>] [--limit <n>] [--direction <b|f>] [--only-text]
```

| 参数                | 说明                                           |
| ------------------- | ---------------------------------------------- |
| `--room-id, -r`   | 房间 ID（必填）                                |
| `--limit, -n`     | 消息数量，默认 50，最大 1000                   |
| `--direction, -d` | `b` 向后取旧消息（默认），`f` 向前取新消息 |
| `--only-text`     | 仅返回文本消息（m.text / m.notice）            |
| `--from`         | 分页起始 token                                 |

返回消息列表，每条包含 event_id、sender、timestamp、msgtype、body 等字段，附带统计信息。

---

## install_matrix-js-sdk.js — 安装依赖

```bash
# 自动检测包管理器并安装
node matrix-tools/install_matrix-js-sdk.js

# 指定版本或包管理器
node matrix-tools/install_matrix-js-sdk.js --version 32.0.0
node matrix-tools/install_matrix-js-sdk.js --package-manager pnpm --save-dev

# 仅检查是否已安装
node matrix-tools/install_matrix-js-sdk.js --check-only
```

---

## 错误码

在脚本的注释中标注。
