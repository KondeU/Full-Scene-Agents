# 存储类 API

存储权限和文件下载功能。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-storage-get

获取存储权限。

**用法：**
```bash
termux-storage-get
```

**说明：**
请求 Android 存储权限，授权后可访问 `/sdcard/` 等存储位置。

**示例：**
```bash
# 请求权限
termux-storage-get

# 之后可以访问
ls /sdcard/
```

**权限要求：**
- READ_EXTERNAL_STORAGE
- WRITE_EXTERNAL_STORAGE

---

## termux-download

下载文件。

**用法：**
```bash
termux-download [选项] <URL>
```

**选项：**
- `-p, --path <路径>`: 保存路径
- `-t, --title <标题>`: 下载标题

**示例：**
```bash
# 下载文件
termux-download https://example.com/file.pdf

# 指定保存路径
termux-download -p /sdcard/Download/file.pdf https://example.com/file.pdf
```

---

## 使用场景

### 文件下载任务

```bash
# 下载并通知
termux-download -p /sdcard/Download/document.pdf https://example.com/doc.pdf
termux-notification --title "下载完成" --content "document.pdf"
```

### 存储初始化

```bash
# 首次使用时请求存储权限
if [ ! -d "/sdcard" ]; then
  termux-storage-get
fi
```