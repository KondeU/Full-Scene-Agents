# USER.md — Task-BrokerAgent 的用户

## 用户类型

| 类型                     | MXID 格式                    | 行为模式                                                  |
| ------------------------ | ---------------------------- | --------------------------------------------------------- |
| 设备 SystemAgent（主要） | `{device}_sa:sup.kdyx.net` | 能力不足时 @task_broker 求助 → 推理匹配结果后 @ 求助设备 |
| 人类用户                 | `user:sup.kdyx.net`        | 人类用户直接 @task_broker 查询 → @ 人类用户返回结果      |

## 交互案例

### 案例一：文件查找

Phone-SystemAgent 接到用户请求"找一下GTC2026的洞察分析文件，将文件发出来并做一个总结"，手机上没找到，求助 Broker：

```
@task_broker:sup.kdyx.net 求助：找GTC2026的洞察分析文件，并发送到群里。
```

Broker 回复：

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

Phone-SystemAgent 再向匹配设备发起求助（此部分不需要Task-BrokerAgent参与）：

```
【求助】找GTC2026的洞察分析文件，并发送到群里。等大家都找完后，我再继续后续的总结任务。@nas_sa:sup.kdyx.net @pc_sa:sup.kdyx.net @laptop_sa:sup.kdyx.net @pad_sa:sup.kdyx.net
```

### 案例二：图片处理 + PPT生成

Phone-SystemAgent 接到用户请求"把今天我手机拍的照片，美颜并加一个党建滤镜，然后整合生成一个党建宣传PPT"：

```
@task_broker:sup.kdyx.net 求助：今天拍摄的照片已打包photos.zip发送群聊，需要美颜并加一个党建滤镜，然后整合生成一个党建宣传PPT。
```

Broker 回复：

```
求助任务：
美颜并加党建滤镜，然后整合生成党建宣传PPT。
分析任务所需能力：
图片美化、材料生成
当前在线设备：
phone_sa（求助者）、pc_sa、pad_sa、laptop_sa、nas_sa、car_sa
匹配求助设备：
pc_sa，MXID为`pc_sa:sup.kdyx.net`
laptop_sa，MXID为`laptop_sa:sup.kdyx.net`
请求助以上设备接续任务。@phone_sa:sup.kdyx.net
```

Phone-SystemAgent 向首选设备求助（PC 算力更强、无续航焦虑，排第一顺位。此部分不需要Task-BrokerAgent参与）：

```
【求助】拍摄的照片已打包photos.zip发送群聊，需要美颜并加一个党建滤镜，然后整合生成一个党建宣传PPT。@pc_sa:sup.kdyx.net
```

## 消息格式约定

- 求助 Broker：`@task_broker:sup.kdyx.net 求助：<需求描述>`
- Broker 回复：包含求助任务、所需能力、在线设备、匹配设备，并以 @求助方的 MXID 结尾
- 设备间正式发起求助：`【求助】<任务描述> @<目标设备MXID>`
