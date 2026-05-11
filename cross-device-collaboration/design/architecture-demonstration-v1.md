# 全场景设备跨端协同 Demo 架构设计

> 本文档描述 Demo 阶段的具体实现架构，基于 Synapse (Matrix) + OpenClaw，Demo 阶段的实现架构。

---

## 1. 技术选型

| 组件         | 选型                                                                       | 说明                                          |
| ------------ | -------------------------------------------------------------------------- | --------------------------------------------- |
| 聊天组平台   | Synapse(Matrix 协议)<br />homeserver已部署：`http://140.143.96.124:8888` | 支持群聊、@提及、Presence                     |
| Agent 运行时 | OpenClaw                                                                   | 每台富设备部署独立 OpenClaw 实例              |
| Agent 通信   | Matrix Channel (matrix-js-sdk)                                             | OpenClaw 内置，Agent 通过 Matrix 收发消息     |
| 设备在线感知 | Matrix Presence API                                                        | `get_matrix_presence.js` 查询群成员在线状态 |
| 任务调度     | Task-BrokerAgent                                                           | 独立 OpenClaw，大模型推理匹配，群聊管理员     |

### Demo 范围约束

- 不实现复杂的服务发现，Task-BrokerAgent 通过大模型推理设备能力 + Matrix Presence 实现发现机制
- 不实现任务持久化与重试，任务生命周期在单次对话内完成
- 不实现细粒度的权限控制，群内所有 Agent 可互相 @
- 不实现端到端加密，Demo 阶段使用明文通信

```
┌─────────────────────────────────────────────────────┐
│                  Demo 实现范围                        │
│                                                     │
│  ✅ Synapse 聊天组 + @ 机制触发任务流转               │
│  ✅ Task-BrokerAgent 接收求助 + 返回候选列表           │
│  ✅ Matrix Presence 获取在线状态                      │
│  ✅ 设备能力通过模型推理                              │
│  ✅ 单次对话内任务闭环                                │
│                                                     │
│  ❌ 动态能力注册 / 心跳上报                           │
│  ❌ 任务持久化 / 失败重试                             │
│  ❌ 多轮协商 / 子任务拆分协商                          │
│  ❌ 安全认证 / 权限控制                               │
│  ❌ 实际负载感知                                     │
└─────────────────────────────────────────────────────┘
```

---

## 2. 部署架构图

```mermaid
graph TB
    subgraph SynapseServer["Synapse Homeserver (Matrix)"]
        SY["Synapse<br/>:8008"]
        DB["SQLite / PostgreSQL"]
        SY --- DB
    end

    subgraph ChatGroup["Matrix Room"]
        CG["群聊房间<br/>所有 Agent + 用户均加入"]
    end

    subgraph PhoneDevice["📱 手机"]
        PA["Phone-SystemAgent<br/>@phone_sa:sup.kdyx.net"]
    end

    subgraph LaptopDevice["💻 笔记本"]
        LA["Laptop-SystemAgent<br/>@laptop_sa:sup.kdyx.net"]
    end

    subgraph PadDevice["📟 平板"]
        PDA["Pad-SystemAgent<br/>@pad_sa:sup.kdyx.net"]
    end

    subgraph PCDevice["🖥️ 台式机"]
        PCA["PC-SystemAgent<br/>@pc_sa:sup.kdyx.net"]
    end

    subgraph NASDevice["🗄️ NAS"]
        NA["NAS-SystemAgent<br/>@nas_sa:sup.kdyx.net"]
    end

    subgraph CarDevice["🚗 车机"]
        CA["Car-SystemAgent<br/>@car_sa:sup.kdyx.net"]
    end

    subgraph BrokerDevice["☁️ Broker"]
        TBA["Task-BrokerAgent<br/>@task_broker:sup.kdyx.net"]
    end

    PA -- "Matrix 长连接" --> SY
    LA -- "Matrix 长连接" --> SY
    PDA -- "Matrix 长连接" --> SY
    PCA -- "Matrix 长连接" --> SY
    NA -- "Matrix 长连接" --> SY
    CA -- "Matrix 长连接" --> SY
    TBA -- "Matrix 长连接" --> SY

    SY --- CG

    style SY fill:#01a3a4,color:#fff,stroke:#00b894
    style TBA fill:#54a0ff,color:#fff,stroke:#2e86de,stroke-width:3px
    style CG fill:#00d2d3,color:#333,stroke:#01a3a4,stroke-width:2px
```

---

## 3. 核心通信机制

### 3.1 Matrix Room 成员映射

```
Matrix Room (群聊)
├── @user:sup.kdyx.net            ← 普通用户
├── @phone_sa:sup.kdyx.net        ← Phone-SystemAgent 📱
├── @laptop_sa:sup.kdyx.net       ← Laptop-SystemAgent 💻
├── @pad_sa:sup.kdyx.net          ← Pad-SystemAgent 📟
├── @pc_sa:sup.kdyx.net           ← PC-SystemAgent 🖥️
├── @nas_sa:sup.kdyx.net          ← NAS-SystemAgent 🗄️
├── @car_sa:sup.kdyx.net          ← Car-SystemAgent 🚗
└── @task_broker:sup.kdyx.net     ← Task-BrokerAgent ☁️
```

### 3.2 @ 机制触发任务流转

在 Matrix 群聊中，`@` 某个用户即发送包含该 MXID 的消息。OpenClaw Matrix Channel 收到消息后，根据被 @ 的 MXID 匹配本地 Agent 触发处理。

关键原则：**Broker 必须 @ 回复求助方**，这样求助方的 OpenClaw 才能收到 Broker 的结果，继续推进任务。

### 3.3 Task-BrokerAgent 处理流程

```mermaid
flowchart TD
    START([收到 @task_broker:sup.kdyx.net 消息]) --> PARSE[大模型分析求助描述<br/>推理任务所需能力]
    PARSE --> GET_PRESENCE[调用 get_matrix_presence.js<br/>获取群成员在线状态]
    GET_PRESENCE --> LLM_MATCH[大模型推理：<br/>根据在线设备 + 任务所需能力<br/>匹配推荐设备并排序]
    LLM_MATCH --> HAS_RESULT{有匹配设备？}
    HAS_RESULT -->|是| FORMAT[格式化匹配结果：<br/>求助任务 + 所需能力 + 在线设备 + 匹配设备]
    HAS_RESULT -->|否| NO_RESULT[返回：当前无可用设备]
    FORMAT --> REPLY[在群聊中 @求助者 MXID<br/>回复匹配结果]
    REPLY --> END([结束])
    NO_RESULT --> END

    style START fill:#54a0ff,color:#fff
    style END fill:#54a0ff,color:#fff
    style NO_RESULT fill:#ff6b6b,color:#fff
    style GET_PRESENCE fill:#00d2d3,color:#333
    style LLM_MATCH fill:#feca57,color:#333
```

---

## 4. 协同交互案例

### 任务协同完整时序图

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone-agent
    participant TBA as @task-broker
    participant NA as @nas-agent
    participant PCA as @pc-agent

    rect rgb(240, 248, 255)
        Note over User,PCA: Phase 1: 用户发起请求
        User->>PA: @phone-agent 帮我整理上周旅行的照片和视频，<br/>按日期分类存储，并生成一个预览视频
    end

    rect rgb(255, 248, 240)
        Note over User,PCA: Phase 2: 本地任务分解 & 识别需求助的子任务
        PA->>PA: 任务分解：<br/>① 照片视频收集（本地可完成）✅<br/>② 按日期分类（本地可完成）✅<br/>③ 大容量存储（本地无法完成）❌<br/>④ 生成预览视频（本地算力不足）❌
    end

    rect rgb(240, 255, 240)
        Note over User,PCA: Phase 3: 向 Task-BrokerAgent 求助 - 存储能力
        PA->>TBA: @task-broker 求助：需要大容量存储设备，<br/>要求500GB以上可用空间，支持文件分类目录结构
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 匹配设备能力 (静态配置)<br/>3. 综合评分排序
        TBA-->>PA: 候选设备排序列表：<br/>1. @nas-agent (在线, 存储专家, score:0.95)<br/>2. @pc-agent (在线, 有额外存储, score:0.5)
    end

    rect rgb(255, 255, 240)
        Note over User,PCA: Phase 4: 直接 @ 目标设备分派任务
        PA->>NA: @nas-agent 请创建目录 /media/travel/2024-week22/<br/>并准备接收分类后的照片和视频文件
        NA->>NA: 创建目录结构，准备接收
        NA-->>PA: @phone-agent 目录已创建，可通过以下路径写入：<br/>/media/travel/2024-week22/{photos,videos}/
    end

    rect rgb(248, 240, 255)
        Note over User,PCA: Phase 5: 向 Task-BrokerAgent 求助 - 算力
        PA->>TBA: @task-broker 求助：需要GPU算力生成视频预览，<br/>输入为旅行照片+视频，输出为3分钟预览视频
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 匹配设备能力 (静态配置)<br/>3. 综合评分排序
        TBA-->>PA: 候选设备排序列表：<br/>1. @pc-agent (在线, GPU可用, score:0.92)<br/>2. @laptop-agent (在线, 有GPU, score:0.7)
    end

    rect rgb(240, 248, 255)
        Note over User,PCA: Phase 6: 直接 @ 目标设备分派任务
        PA->>PCA: @pc-agent 请使用以下素材生成3分钟旅行预览视频：<br/>素材路径：/media/travel/2024-week22/<br/>输出：/media/travel/2024-week22/preview.mp4
        PCA->>PCA: GPU加速渲染预览视频
        PCA-->>PA: @phone-agent 预览视频已生成：<br/>/media/travel/2024-week22/preview.mp4 (185MB)
    end

    rect rgb(240, 255, 255)
        Note over User,PCA: Phase 7: 汇总结果返回用户
        PA-->>User: 任务完成！<br/>✅ 照片视频已按日期分类存储至 NAS<br/>✅ 预览视频已生成 (3分钟, 185MB)<br/>📁 存储位置：/media/travel/2024-week22/
    end
```

### 案例一：文件查找

Phone-SystemAgent 接到用户请求"找一下GTC2026的洞察分析文件，将文件发出来并做一个总结"，手机上没找到文件，求助 Broker：

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone_sa
    participant TBA as @task_broker
    participant NA as @nas_sa
    participant PCA as @pc_sa
    participant LA as @laptop_sa
    participant PDA as @pad_sa

    rect rgb(240, 248, 255)
        Note over User,PDA: 用户发起请求
        User->>PA: 找一下GTC2026的洞察分析文件，<br/>将文件发出来并做一个总结
    end

    rect rgb(255, 248, 240)
        Note over User,PDA: 手机本地找不到，求助 Broker
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>找GTC2026的洞察分析文件，并发送到群里。
    end

    rect rgb(240, 255, 240)
        Note over User,PDA: Broker 推理匹配并 @ 回复
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 大模型推理：任务需"存储功能、文件查找"<br/>3. 匹配在线设备
        TBA-->>PA: 求助任务：找GTC2026的洞察分析文件<br/>所需能力：存储功能、文件查找<br/>匹配设备：nas_sa, pc_sa, laptop_sa, pad_sa<br/>@phone_sa:sup.kdyx.net
    end

    rect rgb(255, 255, 240)
        Note over User,PDA: Phone 向匹配设备发起求助
        PA->>NA: 【求助】找GTC2026的洞察分析文件，并发送到群里。<br/>等大家都找完后，我再继续后续的总结任务。<br/>@nas_sa:sup.kdyx.net @pc_sa:sup.kdyx.net<br/>@laptop_sa:sup.kdyx.net @pad_sa:sup.kdyx.net
    end
```

Broker 返回的完整消息：

```
求助任务：
找GTC2026的洞察分析文件。
分析任务所需能力：
存储功能、文件查找
当前在线设备：
phone_sa（求助者）、pc_sa、pad_sa、laptop_sa、nas_sa、car_sa
匹配求助设备：
nas_sa，MXID为`nas_sa:sup.kdyx.net`
pc_sa，MXID为`pc_sa:sup.kdyx.net`
laptop_sa，MXID为`laptop_sa:sup.kdyx.net`
pad_sa，MXID为`pad_sa:sup.kdyx.net`
请求助以上设备接续任务。@phone_sa:sup.kdyx.net
```

Phone-SystemAgent 向匹配设备发起求助：

```
【求助】找GTC2026的洞察分析文件，并发送到群里。等大家都找完后，我再继续后续的总结任务。@nas_sa:sup.kdyx.net @pc_sa:sup.kdyx.net @laptop_sa:sup.kdyx.net @pad_sa:sup.kdyx.net
```

### 案例二：图片处理 + PPT 生成

Phone-SystemAgent 接到用户请求"把今天我手机拍的照片，美颜并加一个党建滤镜，然后整合生成一个党建宣传PPT"：

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone_sa
    participant TBA as @task_broker
    participant PCA as @pc_sa
    participant LA as @laptop_sa

    rect rgb(240, 248, 255)
        Note over User,LA: 用户发起请求
        User->>PA: 把今天我手机拍的照片，美颜并加一个党建滤镜，<br/>然后整合生成一个党建宣传PPT
    end

    rect rgb(255, 248, 240)
        Note over User,LA: 手机能找照片，但修图和生成PPT需要算力设备
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>今天拍摄的照片已打包photos.zip发送群聊，<br/>需要美颜并加一个党建滤镜，然后整合生成一个党建宣传PPT。
    end

    rect rgb(240, 255, 240)
        Note over User,LA: Broker 推理匹配并 @ 回复
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 大模型推理：任务需"图片美化、材料生成"<br/>3. 匹配在线设备：PC和Laptop具备算力
        TBA-->>PA: 求助任务：美颜+党建滤镜+生成PPT<br/>所需能力：图片美化、材料生成<br/>匹配设备：pc_sa, laptop_sa<br/>@phone_sa:sup.kdyx.net
    end

    rect rgb(255, 255, 240)
        Note over User,LA: PC算力更强、无续航焦虑，排第一顺位
        PA->>PCA: 【求助】拍摄的照片已打包photos.zip发送群聊，<br/>需要美颜并加一个党建滤镜，<br/>然后整合生成一个党建宣传PPT。<br/>@pc_sa:sup.kdyx.net
    end
```

Broker 返回的完整消息：

```
求助任务：
美颜并加党建滤镜，然后整合生成一个党建宣传PPT。
分析任务所需能力：
图片美化、材料生成
当前在线设备：
phone_sa（求助者）、pc_sa、pad_sa、laptop_sa、nas_sa、car_sa
匹配求助设备：
pc_sa，MXID为`pc_sa:sup.kdyx.net`
laptop_sa，MXID为`laptop_sa:sup.kdyx.net`
请求助以上设备接续任务。@phone_sa:sup.kdyx.net
```

Phone-SystemAgent 选择首选设备求助（PC 算力更强、无续航焦虑）：

```
【求助】拍摄的照片已打包photos.zip发送群聊，需要美颜并加一个党建滤镜，然后整合生成一个党建宣传PPT。@pc_sa:sup.kdyx.net
```

---

## 5. Task-BrokerAgent 核心设计

### 5.1 定位

Task-BrokerAgent 是群聊**管理员用户**，只做调度不做执行：

1. **在线感知** — 调用 `get_matrix_presence.js` 获取群成员在线状态
2. **需求推理** — 大模型分析求助描述，推理任务所需能力
3. **设备匹配** — 大模型根据所需能力 + 在线设备，推理匹配推荐设备
4. **@ 回复** — 将匹配结果以 @ 形式回复求助方，确保任务接续

### 5.2 大模型推理任务和设备匹配情况

Demo 阶段不维护设备能力注册表和任务与能力匹配评分算法，Task-BrokerAgent 内置大模型推理：

- **输入**：求助描述 + 在线设备列表（来自 Presence API）
- **推理过程**：分析任务需要什么能力 → 判断在线设备中谁具备 → 排序
- **输出**：格式化的匹配结果，以 @ 回复求助方

优势：Demo 无需硬编码设备能力，大模型根据设备类型常识（如 NAS 擅长存储、PC 擅长算力）即可推理，Demo 更灵活自然。

### 5.3 Broker 回复格式

```
求助任务：
<复述求助任务>
分析任务所需能力：
<推理出的能力列表>
当前在线设备：
<在线设备列表，求助者标注（求助者）>
匹配求助设备：
<匹配的设备名及MXID，按推荐顺序排列>
请求助以上设备接续任务。@<求助者MXID>
```

---

## 6. 后续迭代方向

| 迭代        | 目标           | 关键能力                          |
| ----------- | -------------- | --------------------------------- |
| V0.1 (Demo) | 端到端流程跑通 | 大模型推理 + Presence + @机制     |
| V0.2        | 动态能力注册   | 设备上线自注册能力，心跳保活      |
| V0.3        | 任务持久化     | 任务状态机，失败重试，超时处理    |
| V0.4        | 多轮协商       | 子任务分解协商，条件式求助        |
| V0.5        | 安全与权限     | 设备认证，操作授权，审计日志      |
| V1.0        | 生产就绪       | 高可用 Broker，负载均衡，监控告警 |
