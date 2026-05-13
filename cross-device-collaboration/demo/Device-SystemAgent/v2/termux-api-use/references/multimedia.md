# 多媒体类 API

相机、媒体播放和媒体管理功能。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-camera-info

获取设备相机信息。

**用法：**
```bash
termux-camera-info
```

**返回示例：**
```json
[
  {
    "id": "0",
    "facing": "back",
    "jpeg_output_sizes": [{"width": 4160, "height": 3120}],
    "physical_orientation": "landscape"
  },
  {
    "id": "1",
    "facing": "front",
    "jpeg_output_sizes": [{"width": 576, "height": 720}],
    "physical_orientation": "landscape"
  }
]
```

**字段说明：**
- `id`: 相机 ID（用于拍照时指定）
- `facing`: 相机朝向 (back, front)

---

## termux-camera-photo

使用相机拍照。

**用法：**
```bash
termux-camera-photo [选项] <输出文件>
```

**选项：**
- `-c, --camera <id>`: 指定相机 ID（默认 0，后置相机）

**示例：**
```bash
# 后置相机拍照
termux-camera-photo photo.jpg

# 前置相机拍照
termux-camera-photo -c 1 selfie.jpg
```

**权限要求：**
- CAMERA

---

## termux-media-player

控制媒体播放器。

**用法：**
```bash
termux-media-player <命令>
```

**命令：**
- `play`: 播放
- `pause`: 暂停
- `stop`: 停止
- `play <文件>`: 播放指定文件

**示例：**
```bash
# 播放音乐
termux-media-player play /sdcard/Music/song.mp3

# 暂停
termux-media-player pause
```

---

## termux-media-scan

扫描媒体文件让系统识别。

**用法：**
```bash
termux-media-scan <文件或目录>
```

**示例：**
```bash
termux-media-scan /sdcard/DCIM/photo.jpg
```

---

## 使用场景

### 拍照任务

```bash
# 拍照并分享
termux-camera-photo -c 0 /sdcard/photo_$(date +%Y%m%d_%H%M%S).jpg
termux-share /sdcard/photo_*.jpg
```

### 智能相册管理

```bash
# 拍照后扫描到媒体库
PHOTO=/sdcard/DCIM/photo_$(date +%s).jpg
termux-camera-photo -c 0 "$PHOTO"
termux-media-scan "$PHOTO"
termux-notification --title "拍照完成" --content "照片已保存到 $PHOTO"
```