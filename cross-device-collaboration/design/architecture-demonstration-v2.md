# 全场景设备跨端协同 Demo 架构设计 (V2)

> 本文档描述 Demo 阶段的具体实现架构，基于 Synapse (Matrix) + OpenClaw。
> V2 在 V1 基础上新增抽象层任务协同时序图（面向技术决策者），V1 中的案例时序图保留作为业务参考。

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

## 3.5 任务协同抽象时序模型

> 以下时序图是所有跨端协同场景的**统一抽象模型**，涵盖6个标准阶段。任何具体场景（见 `demonstrations.md`）均可映射到这6个阶段。
> 面向技术决策者（CTO/架构师）讲解时使用本图；面向业务决策者（CEO/产品）讲解时使用 `demonstrations.md` 中的案例时序图。

### 3.5.1 六阶段模型定义

| 阶段 | 名称           | 角色           | 核心动作                                         | 说明 |
| ---- | -------------- | -------------- | ------------------------------------------------ | ---- |
| P1   | **请求接入**   | User → 入口设备 | 用户向任意一台设备发起请求                         | 入口设备通常是手机，也可以是其他设备 |
| P2   | **分解自评**   | 入口设备       | 任务分解 + 本地能力自评 → 识别可本地 / 需求助的子任务 | 本地可执行的子任务立即执行，不等待 |
| P3   | **求助调度**   | 入口设备 → Broker | 对每个无法本地完成的子任务，@Broker 求助           | 描述清晰的能力需求，Broker 据此推理匹配 |
| P4   | **推理匹配**   | Broker         | 获取在线状态 → 大模型推理所需能力 → 匹配候选设备 → @回复求助方 | Broker 只调度不执行，候选列表按匹配度排序 |
| P5   | **任务分派**   | 求助方 → 候选设备 | 求助方根据候选列表，@ 目标设备分派子任务           | 使用【求助】前缀，可同时 @ 多设备并行 |
| P6   | **结果汇总**   | 入口设备       | 收集各设备返回的子任务结果 → 汇总整合 → 回复用户   | 全部完成则回复用户；部分完成则继续等待或补充求助 |

### 3.5.2 抽象时序图

```mermaid
sequenceDiagram
    actor User as 👤 用户
    participant Entry as 📱 入口设备<br/>(SystemAgent)
    participant Broker as ☁️ Task-BrokerAgent
    participant DeviceA as 🖥️ 协同设备A<br/>(SystemAgent)
    participant DeviceB as 💻 协同设备B<br/>(SystemAgent)

    rect rgb(230, 240, 255)
        Note over User,DeviceB: P1 · 请求接入
        User->>Entry: 发起任务请求
    end

    rect rgb(255, 245, 230)
        Note over User,DeviceB: P2 · 分解自评
        Entry->>Entry: 任务分解为子任务列表
        Entry->>Entry: 能力自评：<br/>✅ 子任务1 本地可执行<br/>✅ 子任务2 本地可执行<br/>❌ 子任务3 需求助<br/>❌ 子任务4 需求助
        Entry->>Entry: 执行本地子任务
    end

    rect rgb(230, 255, 230)
        Note over User,DeviceB: P3 · 求助调度（可多轮）
        Entry->>Broker: @Broker 求助：<br/>子任务3需要<能力X>
        Entry->>Broker: @Broker 求助：<br/>子任务4需要<能力Y>
        Note over Entry,Broker: 多个不相关子任务可并行求助
    end

    rect rgb(255, 255, 230)
        Note over User,DeviceB: P4 · 推理匹配
        Broker->>Broker: 1. get_matrix_presence()
        Broker->>Broker: 2. 大模型推理所需能力
        Broker->>Broker: 3. 匹配在线设备 + 排序
        Broker-->>Entry: 候选设备列表（子任务3）：<br/>1. DeviceA (匹配度⭐⭐⭐)<br/>2. DeviceB (匹配度⭐⭐)<br/>@Entry
        Broker-->>Entry: 候选设备列表（子任务4）：<br/>1. DeviceB (匹配度⭐⭐⭐)<br/>@Entry
    end

    rect rgb(245, 235, 255)
        Note over User,DeviceB: P5 · 任务分派
        Entry->>DeviceA: 【求助】子任务3描述 @DeviceA
        Entry->>DeviceB: 【求助】子任务4描述 @DeviceB
        Note over Entry,DeviceB: 分派可并行（扇出）<br/>也可按依赖串行分派
        DeviceA->>DeviceA: 执行子任务3
        DeviceB->>DeviceB: 执行子任务4
        DeviceA-->>Entry: @Entry 子任务3结果
        DeviceB-->>Entry: @Entry 子任务4结果
    end

    rect rgb(230, 255, 250)
        Note over User,DeviceB: P6 · 结果汇总
        Entry->>Entry: 汇总：本地结果 + 设备A结果 + 设备B结果
        Entry-->>User: 最终完整结果
    end
```

### 3.5.3 协同模式变体

上述六阶段模型是基础骨架，根据子任务间的依赖关系，可演化为以下协同模式：

```mermaid
graph LR
    subgraph 协同模式变体
        M1["🔀 串行依赖<br/>A完成→B开始"]
        M2["⚡ 扇出并行<br/>一求助，多端同时执行"]
        M3["🔗 链式接力<br/>A→B→C 逐步流转"]
        M4["📥 先汇聚后分析<br/>多端数据→集中→分析"]
        M5["🔀🔀 混合模式<br/>串行+并行组合"]
    end

    style M1 fill:#54a0ff,color:#fff
    style M2 fill:#00d2d3,color:#333
    style M3 fill:#feca57,color:#333
    style M4 fill:#ff6b6b,color:#fff
    style M5 fill:#5f27cd,color:#fff
```

| 模式 | P3-P5 阶段特征 | 典型场景 |
| ---- | -------------- | -------- |
| **串行依赖** | 子任务间有先后依赖，P3→P5 逐轮执行 | 会议录音→转写→归档 |
| **扇出并行** | 一次求助 Broker，P5 阶段同时 @ 多设备 | 出差行程：PC做文档+NAS归档+Car导航 |
| **链式接力** | 子任务产物流经多设备逐步加工 | 文件定位→编辑→批注 |
| **先汇聚后分析** | P5 先让多端数据集中，再由分析设备统一处理 | 健康数据：多端汇总→PC分析 |
| **混合模式** | 上述模式组合 | 旅行影集：收集→集中存储（串行）→剪辑+播放（串行） |

### 3.5.4 防止求助风暴：闭环打破规则

当协同设备（DeviceA）接收到带 `【求助】` 前缀的任务时，说明自己处于**被求助方**角色。如果被求助方发现自己也无法完成全部任务，**禁止再次发起求助**（否则可能形成 A→B→A 的死循环），而是执行以下回退策略：

```
被求助方执行回退策略：
1. 完成能做的部分 → 返回已完成的结果
2. 明确列出无法完成的部分 → 告知求助方
3. @求助方 将部分结果 + 未完成说明返回
4. 由原求助方决定下一步（换设备 / 降级处理 / 告知用户）
```

```mermaid
flowchart TD
    RECV([收到 【求助】任务]) --> EVAL{评估本地能力<br/>能否完成全部？}
    EVAL -->|全部可完成| EXEC[执行全部任务] --> RESULT[返回完整结果 @求助方]
    EVAL -->|部分可完成| PARTIAL[执行可完成部分] --> PARTIAL_RESULT[返回：<br/>✅ 已完成部分 + 结果<br/>❌ 未完成部分 + 原因<br/>@求助方]
    EVAL -->|完全无法完成| CANNOT[返回：<br/>❌ 无法完成 + 原因<br/>@求助方]

    PARTIAL_RESULT --> DECIDE[求助方决定下一步]
    CANNOT --> DECIDE

    DECIDE -->|换设备求助| RETRY[求助方重新 @Broker<br/>说明前一设备失败原因]
    DECIDE -->|降级处理| DOWNGRADE[求助方调整任务<br/>用已有结果降级完成]
    DECIDE -->|告知用户| INFORM[向用户说明<br/>任务部分完成/无法完成]

    style RECV fill:#54a0ff,color:#fff
    style EVAL fill:#feca57,color:#333
    style RESULT fill:#2ecc71,color:#fff
    style PARTIAL_RESULT fill:#e67e22,color:#fff
    style CANNOT fill:#e74c3c,color:#fff
    style DECIDE fill:#9b59b6,color:#fff
```

**关键原则：求助链是单向的，不允许反向传递。求助方拥有最终的调度决策权。**

---

## 4. 协同交互案例

> 以下两个简明案例用于快速理解 @ 机制的工作方式。更丰富的5个高刚海场景详见 `demonstrations.md`。

### 任务协同完整时序图（案例参考）

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
