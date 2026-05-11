# Keep this file empty (or with only comments) to skip heartbeat API calls.

Demo 实现**不需要独立心跳**，设备在线状态完全依赖 Matrix Presence。

## 工作方式

- **查询时机**：每次被 @ 求助时，实时调用 `get_matrix_presence.js`
- **隐式心跳**：各设备 OpenClaw 的 Matrix Channel 长连接状态，即隐式维持 Presence
- **不做缓存**：每次获取最新状态

## Matrix Presence 状态

| Matrix Presence | 含义      | 说明               |
| --------------- | --------- | ------------------ |
| `online`      | 在线      | Matrix 长连接活跃  |
| `unavailable` | 离开/忙碌 | 连接存在但标记离开 |
| `offline`     | 离线      | 连接断开           |

只有online状态才认为能和设备连通。

# Add tasks below when you want the agent to check something periodically.

