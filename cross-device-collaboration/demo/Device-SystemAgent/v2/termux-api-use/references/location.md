# 位置类 API

获取 GPS 和网络定位信息。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-location

获取位置信息。

**用法：**
```bash
termux-location [选项]
```

**选项：**
- `-p, --provider <提供者>`: 位置提供者 (gps, network, passive)

**示例：**
```bash
# 使用 GPS 获取位置
termux-location -p gps

# 使用网络定位（更快但精度较低）
termux-location -p network
```

**返回示例：**
```json
{
  "latitude": 39.9042,
  "longitude": 116.4074,
  "altitude": 50.0,
  "accuracy": 10.0,
  "provider": "gps"
}
```

**字段说明：**
- `latitude`: 纬度
- `longitude`: 经度
- `altitude`: 海拔（米）
- `accuracy`: 精度（米）
- `provider`: 位置提供者

**权限要求：**
- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION

---

## 使用场景

### 位置上报

```bash
# 获取位置并发送
LOCATION=$(termux-location -p gps)
LAT=$(echo "$LOCATION" | jq -r '.latitude')
LON=$(echo "$LOCATION" | jq -r '.longitude')
echo "当前位置: $LAT, $LON"
```

### 跨端协同位置任务

```bash
# 当其他设备需要位置信息时
termux-location -p gps | jq -c '{latitude, longitude, accuracy}'
```

### 导航辅助

```bash
# 检查位置精度
ACCURACY=$(termux-location -p gps | jq -r '.accuracy')
if [ "$ACCURACY" -lt 20 ]; then
  echo "位置精度良好: $ACCURACY 米"
else
  echo "位置精度较低: $ACCURACY 米，建议移动到开阔地带"
fi
```

---

## 注意事项

1. GPS 定位需要在户外或靠近窗户的地方
2. 网络定位精度较低但速度快
3. 部分设备可能不支持 GPS
4. 需要在 Android 设置中开启位置服务