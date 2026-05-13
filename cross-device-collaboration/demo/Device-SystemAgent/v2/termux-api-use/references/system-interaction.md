# 系统交互类 API

剪贴板、通知、Toast、振动、手电筒、音量、指纹和分享功能。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-clipboard-get

获取剪贴板内容。

**用法：**
```bash
termux-clipboard-get
```

---

## termux-clipboard-set

设置剪贴板内容。

**用法：**
```bash
termux-clipboard-set <内容>
```

---

## termux-notification

发送系统通知。

**用法：**
```bash
termux-notification [选项]
```

**选项：**
- `--title <标题>`: 通知标题
- `--content <内容>`: 通知内容
- `--id <ID>`: 通知 ID（用于更新）
- `--sound`: 播放声音
- `--vibrate`: 振动
- `--action <命令>`: 点击执行的命令

**示例：**
```bash
termux-notification --title "任务完成" --content "文件已下载" --sound
```

---

## termux-toast

显示 Toast 提示。

**用法：**
```bash
termux-toast <消息>
```

---

## termux-vibrate

振动设备。

**用法：**
```bash
termux-vibrate [-d <毫秒>]
```

**示例：**
```bash
termux-vibrate -d 500
```

---

## termux-torch

控制手电筒。

**用法：**
```bash
termux-torch [on|off]
```

---

## termux-volume

控制音量。

**用法：**
```bash
termux-volume <stream> <volume>
```

**stream 类型：**
- `alarm`: 闹钟
- `music`: 音乐
- `notification`: 通知
- `ring`: 铃声

**示例：**
```bash
termux-volume music 50
```

---

## termux-fingerprint

指纹认证。

**用法：**
```bash
termux-fingerprint
```

**返回示例：**
```json
{
  "auth_result": "AUTH_RESULT_SUCCESS"
}
```

---

## termux-share

分享内容。

**用法：**
```bash
termux-share [-a <动作>] <文件>
```

**选项：**
- `-a`: 动作 (send, view, edit)

**示例：**
```bash
termux-share /sdcard/photo.jpg
```

---

## 使用场景

### 剪贴板同步

```bash
# 获取剪贴板处理后再设置
CLIP=$(termux-clipboard-get)
termux-clipboard-set "处理后的: $CLIP"
```

### 任务提醒

```bash
# 完成任务通知
termux-notification \
  --title "跨端任务完成" \
  --content "协同任务已执行完毕" \
  --sound \
  --vibrate
```