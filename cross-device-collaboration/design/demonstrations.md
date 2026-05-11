# 全场景跨端协同 — 高刚海场景演示

> 以下5个场景均为高频、刚需、海量用户覆盖的典型用例，覆盖不同设备组合与协同模式，充分体现跨端协同的价值。

---

## 场景一：智能会议纪要生成

> **用户痛点：** 开会时手动记录效率低，会后整理纪要耗时，纪要归档到哪台设备总找不到。
> **协同价值：** 手机录音 → PC转写总结 → NAS归档，全程自动，用户无需操心。

**用户请求：** "帮我记录下午的产品评审会，会后生成纪要并归档"

### 时序图

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone_sa 📱
    participant TBA as @task_broker ☁️
    participant PCA as @pc_sa 🖥️
    participant NA as @nas_sa 🗄️

    rect rgb(240, 248, 255)
        Note over User,NA: Phase 1: 用户发起请求，手机开始录音
        User->>PA: 帮我记录下午的产品评审会，<br/>会后生成纪要并归档
        PA->>PA: 任务分解：<br/>① 会议录音（本地可完成）✅<br/>② 语音转写+总结（需算力）❌<br/>③ 文件归档（需存储）❌
        PA->>PA: 本地执行：开始录音
    end

    rect rgb(255, 248, 240)
        Note over User,NA: Phase 2: 会议结束后，求助 Broker
        PA->>PA: 会议结束，录音完成
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>需要将会议录音转写为文字并生成结构化纪要，<br/>录音文件约120MB，需语音识别和文本总结能力。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"语音识别、文本生成"<br/>3. 匹配：PC（算力强）、Laptop（便携算力）
        TBA-->>PA: 求助任务：会议录音转写+纪要生成<br/>所需能力：语音识别、文本生成<br/>当前在线设备：phone_sa（求助者）、pc_sa、laptop_sa、nas_sa<br/>匹配求助设备：<br/>pc_sa，MXID为`pc_sa:sup.kdyx.net`<br/>laptop_sa，MXID为`laptop_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
    end

    rect rgb(240, 255, 240)
        Note over User,NA: Phase 3: 手机选择PC执行转写，同时求助NAS归档
        PA->>PCA: 【求助】会议录音文件meeting_0305.m4a已发群聊，<br/>请转写为文字并生成结构化纪要（含议题、结论、待办）。<br/>@pc_sa:sup.kdyx.net
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>需要将纪要文件归档到长期存储，需大容量存储能力。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"大容量存储"<br/>3. 匹配：NAS（专业存储）
        TBA-->>PA: 求助任务：纪要文件归档<br/>所需能力：大容量存储<br/>当前在线设备：phone_sa（求助者）、pc_sa、nas_sa<br/>匹配求助设备：<br/>nas_sa，MXID为`nas_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>NA: 【求助】稍后会有纪要文件需要归档，<br/>请在 /documents/meeting/ 下创建 2025-03-05_产品评审会 目录。<br/>@nas_sa:sup.kdyx.net
        NA-->>PA: @phone_sa:sup.kdyx.net 目录已创建：<br/>/documents/meeting/2025-03-05_产品评审会/
    end

    rect rgb(255, 255, 240)
        Note over User,NA: Phase 4: PC完成转写，结果发群聊并归档到NAS
        PCA->>PCA: 语音转写 + 生成结构化纪要
        PCA-->>PA: @phone_sa:sup.kdyx.net 会议纪要已生成：<br/>议题3个、结论5条、待办8项<br/>纪要文件：meeting_minutes_0305.md<br/>@nas_sa:sup.kdyx.net 请将此纪要归档至<br/>/documents/meeting/2025-03-05_产品评审会/
        NA-->>PA: @phone_sa:sup.kdyx.net 已归档：<br/>/documents/meeting/2025-03-05_产品评审会/meeting_minutes_0305.md
    end

    rect rgb(240, 248, 255)
        Note over User,NA: Phase 5: 手机汇总结果回复用户
        PA-->>User: 会议纪要已完成！📋<br/>✅ 录音已转写为文字<br/>✅ 结构化纪要已生成（3议题/5结论/8待办）<br/>✅ 已归档至NAS：/documents/meeting/2025-03-05_产品评审会/
    end
```

### 协同模式分析

| 维度     | 说明                               |
| -------- | ---------------------------------- |
| 触发设备 | Phone（用户入口 + 录音）           |
| 协同设备 | PC（转写+总结）、NAS（归档）       |
| 协同模式 | 串行+并行：录音→转写→归档，NAS建目录与PC转写并行 |
| 关键价值 | 用户只说一句话，录音-转写-归档全链路自动完成 |

---

## 场景二：家庭旅行影集制作

> **用户痛点：** 旅行拍了大量照片视频散落各设备，整理费力，做影集视频更是技术活。
> **协同价值：** 手机收集素材 → NAS集中存储 → PC自动剪辑 → Pad大屏欣赏，各司其职。

**用户请求：** "帮我把上周旅行的照片视频整理一下，做个3分钟的影集视频"

### 时序图

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone_sa 📱
    participant TBA as @task_broker ☁️
    participant NA as @nas_sa 🗄️
    participant PCA as @pc_sa 🖥️
    participant PDA as @pad_sa 📟

    rect rgb(240, 248, 255)
        Note over User,PDA: Phase 1: 用户发起请求
        User->>PA: 帮我把上周旅行的照片视频整理一下，<br/>做个3分钟的影集视频
        PA->>PA: 任务分解：<br/>① 收集手机上的旅行素材（本地可完成）✅<br/>② 汇总其他设备的素材（需存储中转）❌<br/>③ 视频剪辑渲染（需GPU算力）❌<br/>④ 大屏预览（可选）❌
        PA->>PA: 本地执行：收集手机上的旅行照片视频
    end

    rect rgb(255, 248, 240)
        Note over User,PDA: Phase 2: 求助Broker - 存储中转
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>需要汇总多设备旅行素材到统一存储，<br/>手机素材约2GB，需要大容量存储中转。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"大容量存储"<br/>3. 匹配：NAS
        TBA-->>PA: 求助任务：旅行素材集中存储<br/>所需能力：大容量存储、文件管理<br/>当前在线设备：phone_sa（求助者）、nas_sa、pc_sa、pad_sa<br/>匹配求助设备：<br/>nas_sa，MXID为`nas_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>NA: 【求助】请创建旅行素材中转目录，<br/>我先把手机素材传上去，<br/>其他设备也请把素材传到同一目录。<br/>@nas_sa:sup.kdyx.net
        NA-->>PA: @phone_sa:sup.kdyx.net 目录已创建：<br/>/media/travel/2025-week09/
    end

    rect rgb(240, 255, 240)
        Note over User,PDA: Phase 3: 素材集中到NAS，求助PC剪辑
        PA->>PA: 上传手机素材到NAS目录
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>旅行素材已集中到NAS，约5GB，<br/>需要GPU算力剪辑3分钟影集视频。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"GPU算力、视频剪辑"<br/>3. 匹配：PC（GPU强）、Laptop（有GPU）
        TBA-->>PA: 求助任务：3分钟旅行影集视频剪辑<br/>所需能力：GPU算力、视频剪辑<br/>当前在线设备：phone_sa（求助者）、pc_sa、laptop_sa、nas_sa<br/>匹配求助设备：<br/>pc_sa，MXID为`pc_sa:sup.kdyx.net`<br/>laptop_sa，MXID为`laptop_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>PCA: 【求助】旅行素材在 /media/travel/2025-week09/，<br/>共5GB照片+视频，请剪辑3分钟影集，<br/>风格轻松愉快，配背景音乐。<br/>@pc_sa:sup.kdyx.net
    end

    rect rgb(255, 255, 240)
        Note over User,PDA: Phase 4: PC完成剪辑，结果存NAS
        PCA->>PCA: AI辅助选片 + 自动剪辑 + 配乐
        PCA->>NA: @nas_sa:sup.kdyx.net 影集视频已渲染完成，<br/>存入 /media/travel/2025-week09/travel_movie.mp4<br/>（3分12秒，380MB）
        NA-->>PA: @phone_sa:sup.kdyx.net 影集已存储：<br/>/media/travel/2025-week09/travel_movie.mp4
    end

    rect rgb(248, 240, 255)
        Note over User,PDA: Phase 5: 手机通知Pad大屏播放
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>影集视频已完成，需要大屏设备播放预览。
        TBA->>TBA: 1. get_matrix_presence()<br/>2. 推理：需"大屏播放"<br/>3. 匹配：Pad、PC
        TBA-->>PA: 匹配求助设备：<br/>pad_sa，MXID为`pad_sa:sup.kdyx.net`<br/>pc_sa，MXID为`pc_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>PDA: 【求助】请播放旅行影集视频：<br/>/media/travel/2025-week09/travel_movie.mp4<br/>@pad_sa:sup.kdyx.net
    end

    rect rgb(240, 248, 255)
        Note over User,PDA: Phase 6: 手机汇总结果
        PA-->>User: 旅行影集已完成！🎬<br/>✅ 手机素材已收集上传<br/>✅ 全部素材已集中至NAS<br/>✅ 3分钟影集视频已生成<br/>✅ Pad大屏已开始播放预览<br/>📁 视频位置：/media/travel/2025-week09/travel_movie.mp4
    end
```

### 协同模式分析

| 维度     | 说明                                     |
| -------- | ---------------------------------------- |
| 触发设备 | Phone（用户入口 + 素材收集）             |
| 协同设备 | NAS（存储中转）、PC（视频剪辑）、Pad（大屏播放） |
| 协同模式 | 管线式：收集→集中存储→剪辑→播放，前后依赖 |
| 关键价值 | 四端协同，各取所长，从散落素材到成品影集一步到位 |

---

## 场景三：出差行程全流程管理

> **用户痛点：** 出差前要订票订酒店、做行程单，上了车又要重新设导航，文件散落各处。
> **协同价值：** 手机订票 → PC生成行程单 → NAS存档 → Car同步导航，跨端接力无缝衔接。

**用户请求：** "我明天要去深圳出差，帮我安排行程，订机票酒店，做行程单，导航同步到车机"

### 时序图

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone_sa 📱
    participant TBA as @task_broker ☁️
    participant PCA as @pc_sa 🖥️
    participant NA as @nas_sa 🗄️
    participant CA as @car_sa 🚗

    rect rgb(240, 248, 255)
        Note over User,CA: Phase 1: 用户发起请求
        User->>PA: 我明天要去深圳出差，帮我安排行程，<br/>订机票酒店，做行程单，导航同步到车机
        PA->>PA: 任务分解：<br/>① 查询航班+订票（本地可完成）✅<br/>② 预订酒店（本地可完成）✅<br/>③ 生成格式化行程单（需文档编辑）❌<br/>④ 行程单归档（需存储）❌<br/>⑤ 导航同步到车机（需车机）❌
        PA->>PA: 本地执行：查询航班、订票、预订酒店
    end

    rect rgb(255, 248, 240)
        Note over User,CA: Phase 2: 求助Broker - 文档生成 + 存储 + 车机同步
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>出差行程已订好（航班+酒店），<br/>需要1）生成格式化行程单文档<br/>2）行程单归档到长期存储<br/>3）导航路线同步到车机
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"文档生成+存储+车载导航"<br/>3. 匹配：PC（文档）、NAS（存储）、Car（导航）
        TBA-->>PA: 求助任务：行程单生成+归档+车机导航同步<br/>所需能力：文档编辑、文件存储、车载导航<br/>当前在线设备：phone_sa（求助者）、pc_sa、nas_sa、car_sa<br/>匹配求助设备：<br/>pc_sa，MXID为`pc_sa:sup.kdyx.net`<br/>nas_sa，MXID为`nas_sa:sup.kdyx.net`<br/>car_sa，MXID为`car_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
    end

    rect rgb(240, 255, 240)
        Note over User,CA: Phase 3: 手机分派三个子任务（并行）
        PA->>PCA: 【求助】出差行程信息如下：<br/>航班：CA1301 明日07:30-10:15 北京→深圳<br/>酒店：深圳万豪 3月6日-8日<br/>请生成格式化行程单PDF。<br/>@pc_sa:sup.kdyx.net
        PA->>NA: 【求助】请在 /documents/travel/ 下创建出差文件夹，<br/>稍后接收行程单归档。<br/>@nas_sa:sup.kdyx.net
        PA->>CA: 【求助】请预设明日导航路线：<br/>家→首都机场T3（出发06:00）<br/>深圳宝安机场→深圳万豪酒店（到达10:30）<br/>@car_sa:sup.kdyx.net
    end

    rect rgb(255, 255, 240)
        Note over User,CA: Phase 4: 各设备执行并返回结果
        PCA->>PCA: 生成行程单PDF（含航班、酒店、日程）
        PCA->>NA: @nas_sa:sup.kdyx.net 行程单已发送群聊，<br/>请归档到 /documents/travel/深圳出差_0306/
        NA-->>PA: @phone_sa:sup.kdyx.net 目录已创建，行程单已归档：<br/>/documents/travel/深圳出差_0306/itinerary.pdf
        CA-->>PA: @phone_sa:sup.kdyx.net 导航路线已预设：<br/>✅ 06:00 家→首都机场T3<br/>✅ 10:30 深圳机场→万豪酒店
    end

    rect rgb(240, 248, 255)
        Note over User,CA: Phase 5: 手机汇总结果
        PA-->>User: 出差行程已全部安排好！✈️<br/>✅ 机票：CA1301 明日07:30 北京→深圳<br/>✅ 酒店：深圳万豪 3月6-8日<br/>✅ 行程单已生成并归档至NAS<br/>✅ 车机导航已预设（出发+到达路线）<br/>📁 行程单：/documents/travel/深圳出差_0306/itinerary.pdf
    end
```

### 协同模式分析

| 维度     | 说明                                       |
| -------- | ------------------------------------------ |
| 触发设备 | Phone（用户入口 + 订票订酒店）             |
| 协同设备 | PC（行程单）、NAS（归档）、Car（导航同步） |
| 协同模式 | 扇出并行：一个求助，三端同时执行            |
| 关键价值 | 一次请求搞定订票+文档+归档+车机，零手工中转 |

---

## 场景四：跨端文件协作编辑

> **用户痛点：** 在手机上发现一个文件需要修改，但手机编辑体验差；改完后要发给别人审阅，对方用Pad批注。
> **协同价值：** 手机发起 → NAS定位文件 → PC编辑 → Pad批注，跨端接力完成文件全生命周期。

**用户请求：** "帮我把Q1季度报告修改一下，加上最新数据，然后发给领导审阅"

### 时序图

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone_sa 📱
    participant TBA as @task_broker ☁️
    participant NA as @nas_sa 🗄️
    participant PCA as @pc_sa 🖥️
    participant PDA as @pad_sa 📟

    rect rgb(240, 248, 255)
        Note over User,PDA: Phase 1: 用户发起请求
        User->>PA: 帮我把Q1季度报告修改一下，<br/>加上最新数据，然后发给领导审阅
        PA->>PA: 任务分解：<br/>① 找到Q1报告文件（需文件查找）❌<br/>② 修改报告补充数据（需文档编辑+大屏）❌<br/>③ 发给领导审阅（需通讯录）✅<br/>④ 领导在Pad上批注审阅（需Pad）❌
    end

    rect rgb(255, 248, 240)
        Note over User,PDA: Phase 2: 求助Broker - 找文件
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>需要找到Q1季度报告文件，可能在NAS或PC上。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"文件存储、文件查找"<br/>3. 匹配：NAS、PC
        TBA-->>PA: 求助任务：查找Q1季度报告<br/>所需能力：文件存储、文件查找<br/>当前在线设备：phone_sa（求助者）、nas_sa、pc_sa<br/>匹配求助设备：<br/>nas_sa，MXID为`nas_sa:sup.kdyx.net`<br/>pc_sa，MXID为`pc_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>NA: 【求助】请查找Q1季度报告文件。<br/>@nas_sa:sup.kdyx.net
    end

    rect rgb(240, 255, 240)
        Note over User,PDA: Phase 3: NAS找到文件，求助PC编辑
        NA-->>PA: @phone_sa:sup.kdyx.net 已找到：<br/>/documents/reports/Q1_季度报告_v2.docx<br/>（最后修改：3月1日）
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>需要编辑Q1季度报告，补充最新数据，<br/>文件为docx格式，需要大屏+文档编辑能力。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"文档编辑、大屏操作"<br/>3. 匹配：PC、Laptop
        TBA-->>PA: 匹配求助设备：<br/>pc_sa，MXID为`pc_sa:sup.kdyx.net`<br/>laptop_sa，MXID为`laptop_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>PCA: 【求助】请编辑Q1季度报告，<br/>路径：/documents/reports/Q1_季度报告_v2.docx<br/>请补充3月最新销售数据和客户增长数据。<br/>@pc_sa:sup.kdyx.net
    end

    rect rgb(255, 255, 240)
        Note over User,PDA: Phase 4: PC完成编辑，求助Pad审阅
        PCA->>PCA: 打开报告 + 补充数据 + 保存v3
        PCA->>NA: @nas_sa:sup.kdyx.net 报告已更新，<br/>保存为 /documents/reports/Q1_季度报告_v3.docx
        PCA-->>PA: @phone_sa:sup.kdyx.net Q1报告已更新v3：<br/>✅ 补充3月销售数据<br/>✅ 补充客户增长数据<br/>✅ 已保存至NAS
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>报告已更新，需要领导在Pad上手写批注审阅。
        TBA->>TBA: 1. get_matrix_presence()<br/>2. 推理：需"触屏批注、移动阅读"<br/>3. 匹配：Pad
        TBA-->>PA: 匹配求助设备：<br/>pad_sa，MXID为`pad_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
    end

    rect rgb(248, 240, 255)
        Note over User,PDA: Phase 5: Pad批注审阅
        PA->>PDA: 【求助】请审阅Q1季度报告v3并批注：<br/>/documents/reports/Q1_季度报告_v3.docx<br/>@pad_sa:sup.kdyx.net
        PDA->>PDA: 打开报告 + 手写批注 + 保存批注版
        PDA->>NA: @nas_sa:sup.kdyx.net 批注版已保存：<br/>/documents/reports/Q1_季度报告_v3_批注.docx
        PDA-->>PA: @phone_sa:sup.kdyx.net 审阅完成：<br/>✅ 已批注3处修改意见<br/>✅ 批注版已存NAS
    end

    rect rgb(240, 248, 255)
        Note over User,PDA: Phase 6: 手机汇总结果
        PA-->>User: Q1报告已处理完成！📄<br/>✅ 文件已从NAS定位<br/>✅ PC已补充最新数据（v3）<br/>✅ 领导已在Pad上审阅批注<br/>📁 最终版：/documents/reports/Q1_季度报告_v3_批注.docx
    end
```

### 协同模式分析

| 维度     | 说明                                     |
| -------- | ---------------------------------------- |
| 触发设备 | Phone（用户入口 + 通讯录）               |
| 协同设备 | NAS（定位+存储）、PC（编辑）、Pad（批注）|
| 协同模式 | 链式接力：定位→编辑→审阅，每一步依赖上一步 |
| 关键价值 | 文件全生命周期跨端流转，每一步由最合适的设备完成 |

---

## 场景五：家庭健康数据汇总与报告

> **用户痛点：** 各设备上的健康数据分散（手机运动、Pad健康App、PC体检报告），从没整合分析过。
> **协同价值：** 手机采集日常数据 → NAS汇总历史 → PC分析生成报告 → Pad展示，把散落数据变成可用的健康洞察。

**用户请求：** "帮我汇总一下最近三个月的健康数据，生成一份健康分析报告"

### 时序图

```mermaid
sequenceDiagram
    actor User as @user
    participant PA as @phone_sa 📱
    participant TBA as @task_broker ☁️
    participant NA as @nas_sa 🗄️
    participant PCA as @pc_sa 🖥️
    participant PDA as @pad_sa 📟

    rect rgb(240, 248, 255)
        Note over User,PDA: Phase 1: 用户发起请求
        User->>PA: 帮我汇总一下最近三个月的健康数据，<br/>生成一份健康分析报告
        PA->>PA: 任务分解：<br/>① 导出手机运动健康数据（本地可完成）✅<br/>② 汇总其他设备健康数据（需存储集中）❌<br/>③ 数据分析+生成报告（需算力）❌<br/>④ 报告展示（需大屏）❌
        PA->>PA: 本地执行：导出手机3个月运动/心率/睡眠数据
    end

    rect rgb(255, 248, 240)
        Note over User,PDA: Phase 2: 求助Broker - 数据汇总存储
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>需要汇总多设备健康数据到统一存储，<br/>手机健康数据已导出，需要其他设备也导出数据并集中。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"数据存储、数据汇总"<br/>3. 匹配：NAS
        TBA-->>PA: 求助任务：健康数据集中汇总<br/>所需能力：文件存储、数据管理<br/>当前在线设备：phone_sa（求助者）、nas_sa、pc_sa、pad_sa<br/>匹配求助设备：<br/>nas_sa，MXID为`nas_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>NA: 【求助】请创建健康数据汇总目录，<br/>我先上传手机的健康数据。<br/>@nas_sa:sup.kdyx.net
        NA-->>PA: @phone_sa:sup.kdyx.net 目录已创建：<br/>/health/data/2025_Q1/
    end

    rect rgb(240, 255, 240)
        Note over User,PDA: Phase 3: 多设备数据集中到NAS
        PA->>PA: 上传手机健康数据到NAS
        Note over PA: 手机数据已上传至 /health/data/2025_Q1/phone_health.csv
        PA->>PDA: 【求助】请导出Pad上健康App的3个月数据，<br/>上传到 /health/data/2025_Q1/<br/>@pad_sa:sup.kdyx.net
        PDA->>PDA: 导出健康App数据
        PDA->>NA: @nas_sa:sup.kdyx.net Pad健康数据已上传：<br/>/health/data/2025_Q1/pad_health.csv
        PDA-->>PA: @phone_sa:sup.kdyx.net Pad健康数据已上传至NAS
    end

    rect rgb(255, 255, 240)
        Note over User,PDA: Phase 4: 数据集中完毕，求助PC分析
        PA->>TBA: @task_broker:sup.kdyx.net 求助：<br/>健康数据已集中到NAS，需要分析数据并生成健康报告，<br/>含趋势图表和建议，需要算力+文档生成能力。
        TBA->>TBA: 1. get_matrix_presence() 获取在线状态<br/>2. 推理：需"数据分析、文档生成、图表制作"<br/>3. 匹配：PC（最强算力）
        TBA-->>PA: 匹配求助设备：<br/>pc_sa，MXID为`pc_sa:sup.kdyx.net`<br/>laptop_sa，MXID为`laptop_sa:sup.kdyx.net`<br/>请求助以上设备接续任务。@phone_sa:sup.kdyx.net
        PA->>PCA: 【求助】健康数据在 /health/data/2025_Q1/，<br/>请分析3个月数据，生成健康报告，<br/>包含运动/心率/睡眠趋势图表和健康建议。<br/>@pc_sa:sup.kdyx.net
    end

    rect rgb(248, 240, 255)
        Note over User,PDA: Phase 5: PC生成报告，Pad展示
        PCA->>PCA: 数据分析 + 生成图表 + 制作报告
        PCA->>NA: @nas_sa:sup.kdyx.net 健康报告已存入：<br/>/health/reports/2025_Q1_健康分析报告.pdf
        PCA-->>PA: @phone_sa:sup.kdyx.net 健康报告已生成：<br/>✅ 运动趋势：周均步数上升12%<br/>✅ 心率正常，静息心率72bpm<br/>✅ 睡眠质量评分82/100<br/>✅ 建议：增加有氧运动，改善入睡时间
        PA->>PDA: 【求助】请在Pad上展示健康报告：<br/>/health/reports/2025_Q1_健康分析报告.pdf<br/>@pad_sa:sup.kdyx.net
        PDA-->>PA: @phone_sa:sup.kdyx.net 报告已在Pad上打开
    end

    rect rgb(240, 248, 255)
        Note over User,PDA: Phase 6: 手机汇总结果
        PA-->>User: 健康分析报告已生成！💪<br/>✅ 手机运动数据已汇总<br/>✅ Pad健康App数据已汇总<br/>✅ PC已完成数据分析+报告生成<br/>✅ 报告已在Pad上展示<br/>📊 关键发现：运动量↑12%，睡眠评分82分<br/>📁 报告位置：/health/reports/2025_Q1_健康分析报告.pdf
    end
```

### 协同模式分析

| 维度     | 说明                                             |
| -------- | ------------------------------------------------ |
| 触发设备 | Phone（用户入口 + 运动数据采集）                 |
| 协同设备 | NAS（数据汇总存储）、Pad（数据源+展示）、PC（分析）|
| 协同模式 | 先汇聚后分析：多端数据先集中到NAS，再由PC统一分析 |
| 关键价值 | 打通各设备数据孤岛，让分散的健康数据变成可操作洞察 |

---

## 五场景协同模式总结

| 场景 | 协同设备 | 协同模式 | 核心价值 |
| ---- | -------- | -------- | -------- |
| 智能会议纪要 | Phone→PC→NAS | 串行+并行 | 录音→转写→归档全链路自动 |
| 家庭旅行影集 | Phone→NAS→PC→Pad | 管线式 | 四端各司其职，素材到成品一步到位 |
| 出差行程管理 | Phone→PC+NAS+Car | 扇出并行 | 一次求助三端并行执行 |
| 跨端文件协作 | Phone→NAS→PC→Pad | 链式接力 | 文件全生命周期跨端流转 |
| 健康数据报告 | Phone+Pad→NAS→PC→Pad | 先汇聚后分析 | 打通数据孤岛，变数据为洞察 |
