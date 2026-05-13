# 网络类 API

WiFi 网络管理功能。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-wifi-connectioninfo

获取 WiFi 连接信息。

**用法：**
```bash
termux-wifi-connectioninfo
```

**返回示例：**
```json
{
  "ip": "192.168.1.100",
  "ssid": "MyWiFi",
  "rssi": -45
}
```

**字段说明：**
- `ip`: 分配的 IP 地址
- `ssid`: WiFi 名称
- `rssi`: 信号强度（dBm，越接近 0 信号越好）

---

## termux-wifi-enable

启用或禁用 WiFi。

**用法：**
```bash
termux-wifi-enable [true|false]
```

**示例：**
```bash
# 启用 WiFi
termux-wifi-enable true

# 禁用 WiFi
termux-wifi-enable false
```

---

## termux-wifi-scaninfo

扫描 WiFi 网络。

**用法：**
```bash
termux-wifi-scaninfo
```

**返回示例：**
```json
[
  {"ssid": "MyWiFi", "rssi": -45},
  {"ssid": "OtherWiFi", "rssi": -67}
]
```

---

## 使用场景

### WiFi 状态上报

```bash
# 收集 WiFi 信息
WIFI_INFO=$(termux-wifi-connectioninfo | jq -c '{ip, ssid, rssi}')
echo "WiFi: $WIFI_INFO"
```

### 信号检测

```bash
# 检查信号强度
RSSI=$(termux-wifi-connectioninfo | jq -r '.rssi')
if [ "$RSSI" -gt -70 ]; then
  echo "信号良好"
else
  echo "信号较弱"
fi
```