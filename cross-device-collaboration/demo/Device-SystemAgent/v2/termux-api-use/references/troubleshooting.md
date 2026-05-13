# 故障排查与使用技巧

Termux API 的常见问题和最佳实践。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package
- Termux GitHub: https://github.com/termux

## 安装前提

### 安装 Termux API 包

```bash
pkg install termux-api
```

### 安装 Termux:API 应用

必须从 **F-Droid** 安装 Termux:API 应用，**不要**从 Play Store 安装（Play Store 版本已过时）。

- F-Droid: https://f-droid.org/packages/com.termux.api/

---

## 常见问题

### 1. command not found

**原因：** termux-api 包未安装

**解决：**
```bash
pkg install termux-api
which termux-battery-status  # 验证安装
```

---

### 2. permission denied

**原因：** 权限未授予

**解决：**
- 打开 Android 设置
- 找到 Termux:API 应用
- 授予相应权限（相机、位置、短信等）

---

### 3. 传感器不可用

**原因：** 设备不支持该传感器

**解决：**
```bash
# 查看可用传感器
termux-sensor -l
```

---

### 4. 位置获取失败

**原因：** GPS 信号弱或未开启

**解决：**
- 确保位置服务已开启
- 移动到户外或开阔区域
- 尝试网络定位：`termux-location -p network`

---

### 5. 相机拍照失败

**原因：** 相机权限或相机被占用

**解决：**
- 确保 Termux:API 有相机权限
- 关闭其他使用相机的应用

---

## 权限需求对照

| API | 需要的 Android 权限 |
|-----|---------------------|
| termux-camera-photo | CAMERA |
| termux-location | ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION |
| termux-sms-send | SEND_SMS |
| termux-sms-list | READ_SMS |
| termux-contact-list | READ_CONTACTS |
| termux-telephony-call | CALL_PHONE |
| termux-wifi-enable | CHANGE_WIFI_STATE |
| termux-storage-get | READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE |

---

## 最佳实践

### 1. 使用 jq 处理 JSON 输出

Termux API 返回 JSON 格式，建议安装 jq：

```bash
pkg install jq

# 示例：提取电池百分比
termux-battery-status | jq -r '.batteryPercentage'
```

---

### 2. 组合命令

```bash
# 拍照并发送通知
termux-camera-photo photo.jpg && \
termux-notification --title "拍照完成" --content "照片已保存"
```

---

### 3. 错误处理

```bash
# 检查命令是否成功
if termux-camera-photo photo.jpg; then
  echo "拍照成功"
else
  echo "拍照失败"
  termux-toast "拍照失败"
fi
```

---

### 4. 脚本化

将常用操作封装成脚本：

```bash
#!/data/data/com.termux/files/usr/bin/bash
# photo_backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
termux-camera-photo -c 0 "/sdcard/DCIM/backup_${DATE}.jpg"
termux-notification --title "备份完成" --content "照片已保存"
```

---

### 5. 与 OpenClaw 集成

在 OpenClaw 的 TOOLS.md 中定义 Termux API 工具：

```markdown
## Termux API 工具

- `termux-camera-photo`: 拍照工具
- `termux-location`: 位置获取
- `termux-notification`: 通知发送
- `termux-sms-send`: 短信发送
```

---

## 验证 API 可用性

```bash
# 检查所有核心 API
for cmd in termux-battery-status termux-camera-photo termux-location termux-notification; do
  if command -v $cmd >/dev/null; then
    echo "✓ $cmd 可用"
  else
    echo "✗ $cmd 不可用"
  fi
done
```