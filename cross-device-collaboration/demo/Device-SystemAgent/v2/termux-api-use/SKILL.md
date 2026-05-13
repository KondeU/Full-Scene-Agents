---
name: termux-api-use
description: "Termux API 使用技能。让 Termux 中的 OpenClaw 获得调用 Android 宿主机能力的能力，包括相机、位置、短信、电话、剪贴板、通知、传感器、WiFi、存储等。当设备 Agent 需要与 Android 宿主机交互、访问设备硬件功能、执行系统级操作时触发此 Skill。适用于 Termux 环境下的 Android 设备 Agent。"
---
# Termux API Use

通过 Termux API 调用 Android 宿主机能力，让 OpenClaw 在 Android 设备上具备完整的系统交互能力。

## 详细参考文档

本 Skill 提供详细的参考文档，按功能模块拆分。执行具体任务时，请查阅对应的 reference 文件获取完整用法、参数说明、返回格式和最佳实践：

- **设备信息**: 查阅 `references/device-info.md`（电池状态、电话设备信息）
- **多媒体**: 查阅 `references/multimedia.md`（相机、媒体播放、媒体扫描）
- **通讯**: 查阅 `references/communication.md`（联系人、短信、电话）
- **系统交互**: 查阅 `references/system-interaction.md`（剪贴板、通知、Toast、振动、手电筒、音量、指纹、分享）
- **传感器**: 查阅 `references/sensors.md`（加速度计、陀螺仪、光线、气压等）
- **网络**: 查阅 `references/network.md`（WiFi 连接信息、WiFi 控制、WiFi 扫描）
- **存储**: 查阅 `references/storage.md`（存储权限、文件下载）
- **位置**: 查阅 `references/location.md`（GPS 定位、网络定位）
- **故障排查**: 查阅 `references/troubleshooting.md`（常见问题、权限需求、最佳实践）

所有 reference 文件均基于 Termux API 官方文档整理，并提供官方来源链接供验证。

## 前提条件

- Termux 环境
- 已安装 termux-api: `pkg install termux-api`
- Termux:API 应用已安装并授权

## 核心 API

### 设备信息

```bash
# 电池状态
termux-battery-status

# 电话设备信息
termux-telephony-deviceinfo

# WiFi 连接信息
termux-wifi-connectioninfo
```

### 相机

```bash
# 相机信息
termux-camera-info

# 拍照（默认后置相机）
termux-camera-photo -c 0 photo.jpg

# 前置相机拍照
termux-camera-photo -c 1 selfie.jpg
```

### 位置

```bash
# 获取位置（GPS/网络）
termux-location
```

### 通讯

```bash
# 联系人列表
termux-contact-list

# 发送短信
termux-sms-send -n <手机号> -m <消息内容>

# 短信列表
termux-sms-list

# 拨打电话
termux-telephony-call <手机号>
```

### 剪贴板

```bash
# 获取剪贴板内容
termux-clipboard-get

# 设置剪贴板内容
termux-clipboard-set <内容>
```

### 通知与交互

```bash
# 发送通知
termux-notification --title <标题> --content <内容>

# Toast 提示
termux-toast <消息>

# 振动
termux-vibrate [-d <毫秒>]

# 手电筒
termux-torch [on|off]
```

### 传感器

```bash
# 传感器列表
termux-sensor -l

# 获取传感器数据（需要指定传感器）
termux-sensor -s <传感器名> -d <延迟>
```

### 存储

```bash
# 获取存储权限
termux-storage-get

# 下载文件
termux-download -d <目标路径> <URL>
```

### WiFi 控制

```bash
# 启用/禁用 WiFi
termux-wifi-enable [true|false]

# WiFi 扫描
termux-wifi-scaninfo
```

### 媒体

```bash
# 媒体播放控制
termux-media-player [play|pause|stop|info]

# 媒体扫描
termux-media-scan <文件路径>
```

### 音量

```bash
# 设置音量
termux-volume <stream> <volume>

# stream: ring, music, notification, alarm, call
```

### 分享

```bash
# 分享内容
termux-share [-a action] <文件或内容>

# action: send (默认), view, edit
```

### 指纹

```bash
# 指纹认证
termux-fingerprint
```

## 使用场景

### 场景 1：拍照并分享

```bash
# 拍照
termux-camera-photo -c 0 /sdcard/photo_$(date +%Y%m%d_%H%M%S).jpg

# 分享
termux-share /sdcard/photo_*.jpg
```

### 场景 2：位置上报

```bash
# 获取位置
LOCATION=$(termux-location)

# 解析并发送
# 将位置信息发送到 Matrix 群聊或其他服务
```

### 场景 3：剪贴板同步

```bash
# 获取剪贴板
CLIP=$(termux-clipboard-get)

# 处理剪贴板内容
# ...

# 设置剪贴板
termux-clipboard-set "处理后的内容"
```

### 场景 4：通知提醒

```bash
# 任务完成通知
termux-notification \
  --title "任务完成" \
  --content "跨端协同任务已执行完毕" \
  --sound \
  --vibrate 500
```

## 错误处理

### 常见错误

1. **权限不足**
   ```
   Error: permission denied
   ```
   解决：在 Termux:API 应用中授予权限

2. **API 未安装**
   ```
   command not found
   ```
   解决：`pkg install termux-api`

3. **传感器不可用**
   ```
   Error: sensor not available
   ```
   解决：检查设备是否支持该传感器，使用 `termux-sensor -l` 查看可用传感器

### 检查 API 可用性

```bash
# 检查 termux-api 是否安装
which termux-battery-status

# 测试基本功能
termux-battery-status
```

## 与跨端协同的配合

作为 Android 设备 Agent，结合 `cross-device-collaboration` Skill：

1. **作为入口设备**：利用 Termux API 完成本地任务，需要时向 Broker 求助其他设备
2. **作为被求助方**：接收其他设备的求助，利用 Termux API 完成任务后返回结果

示例协同场景：
- **拍照任务**：用户请求拍照 → Android Agent 拍照 → 返回结果
- **位置共享**：其他设备需要位置信息 → Android Agent 获取位置 → 返回坐标
- **短信转发**：其他设备需要发送短信 → Android Agent 发送短信 → 确认发送

## 注意事项

1. **隐私敏感**：相机、位置、联系人、短信等涉及隐私，使用前需用户明确授权
2. **权限要求**：部分 API 需要系统级权限，需在 Android 设置中授予
3. **异步操作**：某些操作（如位置获取）可能耗时，需合理设置超时
4. **设备差异**：不同 Android 设备的传感器、硬件支持不同，需检测可用性
5. **电池优化**：频繁使用传感器会耗电，合理控制使用频率

## 官方资源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package
- Termux:API 应用（F-Droid）: https://f-droid.org/packages/com.termux.api/

**注意**: Termux:API 应用必须从 F-Droid 安装，Play Store 版本已过时。

## 详细参考

执行具体任务时查阅对应的 reference 文件（详见文档开头的"详细参考文档"章节）。