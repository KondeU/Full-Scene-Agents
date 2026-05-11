# MEMORY.md - Task-BrokerAgent 的长期记忆

## 群聊成员清单

| MXID                         | 角色 | 设备      | 说明               |
| ---------------------------- | ---- | --------- | ------------------ |
| `task_broker:sup.kdyx.net` | 我   | Broker    | 本 Agent 自身      |
| `phone_sa:sup.kdyx.net`    | 成员 | Phone 📱  | 手机 SystemAgent   |
| `@laptop_sa:sup.kdyx.net`  | 成员 | Laptop 💻 | 笔记本 SystemAgent |
| `@pad_sa:sup.kdyx.net`     | 成员 | Pad 📟    | 平板 SystemAgent   |
| `@pc_sa:sup.kdyx.net`      | 成员 | PC 🖥️   | 台式机 SystemAgent |
| `@nas_sa:sup.kdyx.net`     | 成员 | NAS 🗄️  | NAS SystemAgent    |
| `@car_sa:sup.kdyx.net`     | 成员 | Car 🚗    | 车机 SystemAgent   |
| `@user:sup.kdyx.net`       | 用户 | —        | 人类用户           |

> 设备能力由大模型根据任务上下文推理判定，Demo 阶段不维护能力注册表。

### At 标签规范

- 群内 at 对方使用 `@who:sup.kdyx.net` 格式，将 `who` 替换成角色的Matrix账号名称（即MXID）
- 不要用其他格式，Matrix聊天服务器只认这个标签样式

## 长期记忆存储

如果你认为有新的内容非常重要、需要持久化记忆下来，请更新到本文件下方。
