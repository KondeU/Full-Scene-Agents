# 全场景设备跨端协同架构设计

## 1. 当前实现：用户中转模式（Star Topology）

> 用户作为中转中心，分别和不同设备的 OpenClaw 连接。设备间无法直接通信，任务无法跨端时只能返回用户，由用户手动中转。

### 1.1 组件图（Component Diagram）

```mermaid
graph TB
    subgraph User["👤 用户（中转中心）"]
        U[User]
    end

    subgraph Phone["📱 手机"]
        PA[Phone-SystemAgent<br/>OpenClaw Instance]
    end

    subgraph Laptop["💻 笔记本"]
        LA[Laptop-SystemAgent<br/>OpenClaw Instance]
    end

    subgraph Pad["📟 平板"]
        PDA[Pad-SystemAgent<br/>OpenClaw Instance]
    end

    subgraph PC["🖥️ 台式机"]
        PCA[PC-SystemAgent<br/>OpenClaw Instance]
    end

    subgraph NAS["🗄️ NAS"]
        NA[NAS-SystemAgent<br/>OpenClaw Instance]
    end

    subgraph Car["🚗 车机"]
        CA[Car-SystemAgent<br/>OpenClaw Instance]
    end

    U -- "channel-1<br/>请求/响应" --> PA
    PA -- "无法完成时<br/>只能返回用户" --> U

    U -- "channel-2<br/>请求/响应" --> LA
    LA -- "无法完成时<br/>只能返回用户" --> U

    U -- "channel-3<br/>请求/响应" --> PDA
    PDA -- "无法完成时<br/>只能返回用户" --> U

    U -- "channel-4<br/>请求/响应" --> PCA
    PCA -- "无法完成时<br/>只能返回用户" --> U

    U -- "channel-5<br/>请求/响应" --> NA
    NA -- "无法完成时<br/>只能返回用户" --> U

    U -- "channel-6<br/>请求/响应" --> CA
    CA -- "无法完成时<br/>只能返回用户" --> U

    style U fill:#ff6b6b,color:#fff,stroke:#c0392b
    style PA fill:#feca57,color:#333,stroke:#f39c12
    style LA fill:#feca57,color:#333,stroke:#f39c12
    style PDA fill:#feca57,color:#333,stroke:#f39c12
    style PCA fill:#feca57,color:#333,stroke:#f39c12
    style NA fill:#feca57,color:#333,stroke:#f39c12
    style CA fill:#feca57,color:#333,stroke:#f39c12
```

### 1.2 当前模式时序图（Sequence Diagram）

```mermaid
sequenceDiagram
    actor User as 👤 用户
    participant PA as 📱 Phone-SystemAgent
    participant NA as 🗄️ NAS-SystemAgent

    User->>PA: 发起任务请求
    PA->>PA: 任务分解 & 本地处理
    PA-->>PA: 发现子任务无法本地完成<br/>（如需要NAS存储能力）

    Note over PA,User: ❌ 设备间无法直接通信<br/>只能将失败结果返回用户

    PA-->>User: 返回结果：任务无法完成<br/>（需要NAS协助）
    Note over User: 用户手动判断<br/>需要找NAS帮忙

    User->>NA: 手动转发子任务
    NA->>NA: 处理子任务
    NA-->>User: 返回子任务结果

    Note over User: 用户手动汇总结果

    User->>PA: 手动转达NAS的结果
    PA->>PA: 继续处理
    PA-->>User: 返回最终结果
```

### 1.3 当前模式问题分析

| 问题 | 描述 |
|------|------|
| **单点瓶颈** | 用户是唯一的中转节点，所有跨设备任务必须经过用户 |
| **手动中转** | 设备间无法直接通信，用户需要理解任务依赖并手动分配 |
| **体验割裂** | 一次请求可能需要多轮用户交互才能完成 |
| **能力孤岛** | 每台设备的能力被隔离，无法自动发现和组合 |
| **延迟高** | 用户介入的等待时间 + 理解判断时间 = 不可控延迟 |

---

## 2. 新实现：Task-BrokerAgent 协同模式

> 所有富设备的 SystemAgent 与 Task-BrokerAgent 处于同一聊天组中，通过 @ 机制实现任务流转。设备搞不定时主动求助 Task-BrokerAgent，获取候选设备列表后直接 @ 目标设备协同。

### 2.1 组件图（Component Diagram）

```mermaid
graph TB
    subgraph ChatGroup["💬 协同聊天组（Shared Chat Group）"]
        TBA[Task-BrokerAgent<br/>任务调度 & 设备能力注册中心]
        PA[Phone-SystemAgent<br/>OpenClaw Instance]
        LA[Laptop-SystemAgent<br/>OpenClaw Instance]
        PDA[Pad-SystemAgent<br/>OpenClaw Instance]
        PCA[PC-SystemAgent<br/>OpenClaw Instance]
        NA[NAS-SystemAgent<br/>OpenClaw Instance]
        CA[Car-SystemAgent<br/>OpenClaw Instance]
    end

    U[👤 用户]

    U -- "任意设备入口<br/>（如手机）" --> PA

    PA -. "@Task-BrokerAgent<br/>求助：谁有存储能力？" .-> TBA
    TBA -. "返回排序候选列表<br/>1. NAS-SystemAgent ⭐⭐⭐<br/>2. PC-SystemAgent ⭐⭐" .-> PA
    PA -. "@NAS-SystemAgent<br/>请帮忙处理存储子任务" .-> NA
    NA -. "存储任务完成<br/>结果返回" .-> PA

    PA -. "@Task-BrokerAgent<br/>求助：谁有算力？" .-> TBA
    TBA -. "返回排序候选列表<br/>1. PC-SystemAgent ⭐⭐⭐<br/>2. Laptop-SystemAgent ⭐⭐" .-> PA
    PCA -. "被@后执行计算子任务" .-> PA

    style TBA fill:#54a0ff,color:#fff,stroke:#2e86de
    style PA fill:#5f27cd,color:#fff,stroke:#341f97
    style LA fill:#5f27cd,color:#fff,stroke:#341f97
    style PDA fill:#5f27cd,color:#fff,stroke:#341f97
    style PCA fill:#5f27cd,color:#fff,stroke:#341f97
    style NA fill:#5f27cd,color:#fff,stroke:#341f97
    style CA fill:#5f27cd,color:#fff,stroke:#341f97
    style U fill:#ff6b6b,color:#fff,stroke:#c0392b
```

### 2.2 核心架构类图（Class Diagram）

```mermaid
classDiagram
    class SystemAgent {
        +String deviceId
        +String deviceType
        +String channel
        +List~Capability~ capabilities
        +AgentStatus status
        +processTask(task: Task) TaskResult
        +decomposeTask(task: Task) List~Task~
        +requestHelp(description: String) HelpResponse
        +delegateTask(target: SystemAgent, task: Task) TaskResult
    }

    class TaskBrokerAgent {
        -Map~String, DeviceProfile~ deviceRegistry
        -Map~String, AgentStatus~ statusMap
        +registerDevice(agent: SystemAgent) void
        +deregisterDevice(deviceId: String) void
        +updateStatus(deviceId: String, status: AgentStatus) void
        +findCandidates(description: String) List~DeviceCandidate~
        +rankByCapability(candidates: List~, description: String) List~DeviceCandidate~
        +reportTaskResult(taskId: String, result: TaskResult) void
    }

    class DeviceProfile {
        +String deviceId
        +String deviceType
        +List~Capability~ capabilities
        +Number cpuScore
        +Number memScore
        +Number storageScore
        +Number networkScore
    }

    class Capability {
        +String name
        +String category
        +Number proficiency
        +Map~String, String~ params
    }

    class AgentStatus {
        <<enumeration>>
        ONLINE
        BUSY
        IDLE
        OFFLINE
    }

    class Task {
        +String taskId
        +String description
        +String requiredCapability
        +TaskPriority priority
        +TaskStatus status
        +String parentId
        +Number createdAt
    }

    class TaskResult {
        +String taskId
        +Boolean success
        +String output
        +Number duration
    }

    class DeviceCandidate {
        +String deviceId
        +DeviceProfile profile
        +Number matchScore
        +AgentStatus currentStatus
    }

    class HelpResponse {
        +String requestId
        +List~DeviceCandidate~ candidates
        +String suggestion
    }

    TaskBrokerAgent "1" --> "*" SystemAgent : manages
    TaskBrokerAgent "1" --> "*" DeviceProfile : stores
    TaskBrokerAgent --> "*" DeviceCandidate : ranks
    SystemAgent --> "*" Capability : has
    SystemAgent --> "*" Task : processes
    SystemAgent --> TaskResult : produces
    SystemAgent --> HelpResponse : receives
    DeviceProfile --> "*" Capability : describes
    DeviceCandidate --> DeviceProfile : references
    DeviceCandidate --> AgentStatus : has
    Task --> TaskResult : yields
```

### 2.3 协同时序图（Sequence Diagram）

```mermaid
sequenceDiagram
    actor User as 👤 用户
    participant PA as 📱 Phone-SystemAgent
    participant TBA as 🤖 Task-BrokerAgent
    participant NA as 🗄️ NAS-SystemAgent
    participant PCA as 🖥️ PC-SystemAgent

    Note over User,PCA: ===== 用户只需向任意一台设备发送请求 =====

    User->>PA: 发起复杂任务请求

    Note over PA: 本地进行任务分解

    PA->>PA: 任务分解 & 本地可执行部分处理

    Note over PA,TBA: ===== 子任务1：需要大容量存储（本地无法完成）=====

    PA->>TBA: @Task-BrokerAgent<br/>求助：需要大容量存储能力
    TBA->>TBA: 查询设备在线状态 & 能力匹配
    TBA-->>PA: 返回排序候选列表：<br/>1. NAS-SystemAgent (score:0.95, IDLE)<br/>2. PC-SystemAgent (score:0.6, BUSY)

    PA->>NA: @NAS-SystemAgent<br/>请处理存储子任务
    NA->>NA: 执行存储任务
    NA-->>PA: 返回存储任务结果 ✅

    Note over PA,TBA: ===== 子任务2：需要高算力（本地无法完成）=====

    PA->>TBA: @Task-BrokerAgent<br/>求助：需要GPU算力
    TBA->>TBA: 查询设备在线状态 & 能力匹配
    TBA-->>PA: 返回排序候选列表：<br/>1. PC-SystemAgent (score:0.92, IDLE)<br/>2. Laptop-SystemAgent (score:0.7, BUSY)

    PA->>PCA: @PC-SystemAgent<br/>请处理计算子任务
    PCA->>PCA: 执行计算任务
    PCA-->>PA: 返回计算任务结果 ✅

    Note over PA: 汇总所有子任务结果

    PA-->>User: 返回最终完整结果 ✅

    Note over User,PCA: ✅ 用户全程无需中转，自动跨端协同完成
```

### 2.4 设备注册与心跳时序图

```mermaid
sequenceDiagram
    participant PA as 📱 Phone-SystemAgent
    participant LA as 💻 Laptop-SystemAgent
    participant NA as 🗄️ NAS-SystemAgent
    participant TBA as 🤖 Task-BrokerAgent

    Note over PA,TBA: ===== 设备上线注册 =====

    PA->>TBA: 注册：deviceId, capabilities, status=ONLINE
    TBA->>TBA: 存入 DeviceProfile & 更新状态
    TBA-->>PA: 注册成功确认

    LA->>TBA: 注册：deviceId, capabilities, status=ONLINE
    TBA->>TBA: 存入 DeviceProfile & 更新状态
    TBA-->>LA: 注册成功确认

    NA->>TBA: 注册：deviceId, capabilities, status=ONLINE
    TBA->>TBA: 存入 DeviceProfile & 更新状态
    TBA-->>NA: 注册成功确认

    Note over PA,TBA: ===== 心跳保活 & 状态更新 =====

    loop 每 N 秒
        PA->>TBA: heartbeat: status=BUSY, load=0.7
        LA->>TBA: heartbeat: status=IDLE, load=0.1
        NA->>TBA: heartbeat: status=IDLE, load=0.2
        TBA->>TBA: 更新各设备状态 & 负载
    end

    Note over PA,TBA: ===== 设备离线 =====

    NA--xtba: 心跳超时
    TBA->>TBA: 标记 NAS-SystemAgent = OFFLINE
    Note over TBA: 后续求助查询将排除离线设备
```

### 2.5 部署图（Deployment Diagram）

```mermaid
graph TB
    subgraph PhoneDevice["📱 手机"]
        PO[OpenClaw Runtime]
        PA[Phone-SystemAgent]
        PO --- PA
    end

    subgraph LaptopDevice["💻 笔记本"]
        LO[OpenClaw Runtime]
        LA[Laptop-SystemAgent]
        LO --- LA
    end

    subgraph PadDevice["📟 平板"]
        PDO[OpenClaw Runtime]
        PDA[Pad-SystemAgent]
        PDO --- PDA
    end

    subgraph PCDevice["🖥️ 台式机"]
        PCO[OpenClaw Runtime]
        PCA[PC-SystemAgent]
        PCO --- PCA
    end

    subgraph NASDevice["🗄️ NAS"]
        NO[OpenClaw Runtime]
        NA[NAS-SystemAgent]
        NO --- NA
    end

    subgraph CarDevice["🚗 车机"]
        CO[OpenClaw Runtime]
        CA[Car-SystemAgent]
        CO --- CA
    end

    subgraph BrokerService["☁️ Task-BrokerAgent 服务"]
        TBO[OpenClaw Runtime]
        TBA[Task-BrokerAgent]
        TBO --- TBA
    end

    subgraph ChatGroup["💬 协同聊天组"]
        CG["Shared Chat Group<br/>（所有Agent通过@机制通信）"]
    end

    PA --- CG
    LA --- CG
    PDA --- CG
    PCA --- CG
    NA --- CG
    CA --- CG
    TBA --- CG

    style CG fill:#00d2d3,color:#333,stroke:#01a3a4,stroke-width:2px
    style TBA fill:#54a0ff,color:#fff,stroke:#2e86de
    style PA fill:#5f27cd,color:#fff,stroke:#341f97
    style LA fill:#5f27cd,color:#fff,stroke:#341f97
    style PDA fill:#5f27cd,color:#fff,stroke:#341f97
    style PCA fill:#5f27cd,color:#fff,stroke:#341f97
    style NA fill:#5f27cd,color:#fff,stroke:#341f97
    style CA fill:#5f27cd,color:#fff,stroke:#341f97
```

---

## 3. 两种模式对比

### 3.1 拓扑对比

| 维度 | 当前模式（用户中转） | 新模式（Task-BrokerAgent协同） |
|------|---------------------|-------------------------------|
| **拓扑结构** | 星型（User为中心） | 网状（Chat Group + Broker） |
| **通信方式** | 用户 ↔ 单设备 | 设备 ↔ 设备（@机制） |
| **跨端协同** | ❌ 不支持 | ✅ 自动求助 & 任务分派 |
| **能力发现** | ❌ 无（用户靠记忆） | ✅ Task-BrokerAgent 维护能力注册表 |
| **负载感知** | ❌ 无 | ✅ 心心跳 + 状态上报 |
| **候选排序** | ❌ 无 | ✅ 综合评分排序 |
| **用户介入** | 每次跨端必须介入 | 仅发起请求，全程自动 |
| **容错** | 依赖用户判断 | Broker自动排除离线设备 |

### 3.2 关键设计决策

1. **聊天组 + @机制**：所有 SystemAgent 和 Task-BrokerAgent 在同一聊天组，通过 @ 触发任务流转，与 OpenClaw 的 channel 机制天然契合
2. **Broker 不执行任务**：Task-BrokerAgent 仅做调度，不承担具体任务执行，避免单点性能瓶颈
3. **求助不中断**：设备发现自己搞不定时，不返回用户，而是先向 Broker 求助，实现"静默协同"
4. **候选排序**：Broker 返回的候选列表按综合评分排序，求助方按序选择，提高匹配效率
5. **心跳保活**：定期心跳确保设备在线状态准确，离线设备自动排除
