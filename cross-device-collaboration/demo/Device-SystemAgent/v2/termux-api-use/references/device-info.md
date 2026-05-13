# 设备信息类 API

获取 Android 设备的硬件和系统状态信息。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-battery-status

获取电池状态信息。

**用法：**
```bash
termux-battery-status
```

**返回示例：**
```json
{
  "batteryHealth": "GOOD",
  "batteryPercentage": 85,
  "batteryStatus": "DISCHARGING",
  "batteryTemperature": "32.0"
}
```

**字段说明：**
- `batteryHealth`: 电池健康状态 (GOOD, OVERHEAT, DEAD, OVER_VOLTAGE, UNSPECIFIED_FAILURE, COLD)
- `batteryPercentage`: 电池百分比 (0-100)
- `batteryStatus`: 电池状态 (CHARGING, DISCHARGING, FULL, NOT_CHARGING)
- `batteryTemperature`: 电池温度（摄氏度）

---

## termux-telephony-deviceinfo

获取电话设备信息。

**用法：**
```bash
termux-telephony-deviceinfo
```

**返回示例：**
```json
{
  "data_enabled": true,
  "data_activity": "INOUT",
  "data_state": "CONNECTED",
  "device_id": "imei_value",
  "phone_count": 2,
  "phone_type": "GSM"
}
```

**字段说明：**
- `data_enabled`: 数据是否启用
- `data_state`: 数据连接状态 (CONNECTED, DISCONNECTED, CONNECTING, SUSPENDED)
- `device_id`: 设备 IMEI
- `phone_count`: 电话数量（双卡双待）
- `phone_type`: 电话类型 (GSM, CDMA, SIP, NONE)

**权限要求：**
- READ_PHONE_STATE

---

## 使用场景

### 监控电池状态

```bash
# 检查电池是否正在充电
termux-battery-status | grep -q "CHARGING" && echo "正在充电"

# 低电量提醒
BATTERY=$(termux-battery-status | jq -r '.batteryPercentage')
if [ "$BATTERY" -lt 20 ]; then
  termux-notification --title "低电量警告" --content "电量仅剩 ${BATTERY}%"
fi
```

### 获取设备信息上报

```bash
# 收集设备信息
DEVICE_INFO=$(termux-telephony-deviceinfo | jq -c '{phone_type, phone_count}')
BATTERY_INFO=$(termux-battery-status | jq -c '.')
echo "{\"device\": $DEVICE_INFO, \"battery\": $BATTERY_INFO}"
```