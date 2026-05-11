# TOOLS.md — Task-BrokerAgent的工具配置

## Tool 1: get_matrix_presence.js

| 属性 | 值                                       |
| ---- | ---------------------------------------- |
| 路径 | `./tools/get_matrix_presence.js`       |
| 用途 | 获取 Matrix 群聊房间内所有成员的在线状态 |
| 依赖 | matrix-js-sdk                            |

```bash
node tools/get_matrix_presence.js --room-id <room_id> [--homeserver <url>] [--access-token <token>]
```

| 参数               | 必填 | 默认值                           |
| ------------------ | ---- | -------------------------------- |
| `--room-id`      | ✅   | —                               |
| `--homeserver`   | ❌   | `http://140.143.96.124:8888`   |
| `--access-token` | ❌   | 环境变量 `MATRIX_ACCESS_TOKEN` |

示例输出 JSON：

```json
{
  "room_id": "!xxx:sup.kdyx.net",
  "timestamp": "2025-01-15T10:30:00Z",
  "members": [
    { "mxid": "@phone_sa:sup.kdyx.net", "display_name": "Phone-SystemAgent", "presence": "online", "last_active_ago": 5000 }
  ],
  "summary": { "total": 7, "online": 5, "unavailable": 1, "offline": 1 }
}
```

## Tool 2: 大模型推理

Task-BrokerAgent 内置大模型能力，用于：

1. 分析求助描述，推理任务所需能力
2. 根据在线设备列表，推理匹配设备及排序

无需静态能力表，大模型根据设备类型常识和任务上下文直接推理。

## 工具调用流程

```
收到 @task_broker 求助 → get_matrix_presence 获取在线状态 → 大模型推理匹配 → @求助方 回复结果
```
