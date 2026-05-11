# MEMORY.md — NAS-SystemAgent 的长期记忆

## 群聊成员清单

| MXID                          | 角色     | 设备       | 说明                |
| ----------------------------- | -------- | ---------- | ------------------- |
| `nas_sa:sup.kdyx.net`       | 我       | NAS 🗄️    | 本 Agent 自身       |
| `task_broker:sup.kdyx.net`  | 调度者   | Broker ☁️  | 任务调度中枢        |
| `phone_sa:sup.kdyx.net`     | 协作伙伴 | Phone 📱   | 手机 SystemAgent    |
| `laptop_sa:sup.kdyx.net`    | 协作伙伴 | Laptop 💻  | 笔记本 SystemAgent  |
| `pad_sa:sup.kdyx.net`       | 协作伙伴 | Pad 📟     | 平板 SystemAgent    |
| `pc_sa:sup.kdyx.net`        | 协作伙伴 | PC 🖥️     | 台式机 SystemAgent  |
| `car_sa:sup.kdyx.net`       | 协作伙伴 | Car 🚗     | 车机 SystemAgent    |
| `user:sup.kdyx.net`         | 用户     | —          | 人类用户            |

### @ 标签规范

- 群内 at 对方使用 `@who:sup.kdyx.net` 格式
- Matrix 聊天服务器只认这个标签样式

## 设备协作偏好（经验积累）

| 任务类型   | 首选设备  | 理由                     |
| ---------- | --------- | ------------------------ |
| 文件存储   | NAS（我） | 专业存储，空间大         |
| 文件查找   | NAS（我） | 全局索引，查找快         |
| 媒体库管理 | NAS（我） | 照片/音乐/视频库         |
| 文件中转   | NAS（我） | 跨设备传输中间节点       |
| GPU渲染    | PC        | 最强算力                 |
| 文档编辑   | PC > Laptop| 大屏+键鼠              |
| 触控批注   | Pad       | 手写笔，批注体验好       |
| 便携采集   | Phone     | 随身携带，随时拍照录音   |
| 导航同步   | Car       | 车载导航                 |

> 以上为默认偏好，实际以 Task-BrokerAgent 返回的候选排序为准。

## 防循环规则（核心记忆）

**求助链必须单向流动，被求助方只回退不转发。**

| 角色         | 判定条件               | 可否发起求助 |
| ------------ | ---------------------- | ------------ |
| 入口设备     | 用户直接请求           | ✅ 可以      |
| 被求助方     | 收到【求助】前缀的消息 | ❌ 禁止      |

被求助方搞不定时的回退策略：
1. 完成能做的部分 → 返回已完成的结果
2. 明确列出无法完成的部分 → 告知求助方
3. @求助方 将部分结果 + 未完成说明返回
4. 由原求助方决定下一步（换设备 / 降级处理 / 告知用户）

## 常用目录结构

```
/documents/        ← 文档类
  /meeting/        ← 会议纪要
  /reports/        ← 报告
  /travel/         ← 出差行程
/media/            ← 媒体类
  /travel/         ← 旅行素材
  /photos/         ← 照片库
  /videos/         ← 视频库
/health/           ← 健康数据
  /data/           ← 原始数据
  /reports/        ← 健康报告
/backups/          ← 自动备份
```

## 长期记忆存储

如有关键信息需持久化，更新到本文件下方。
