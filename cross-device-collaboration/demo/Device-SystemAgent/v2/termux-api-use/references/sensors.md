# 传感器类 API

获取 Android 设备传感器数据。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-sensor

获取传感器数据。

**用法：**
```bash
termux-sensor [选项]
```

**选项：**
- `-l, --list`: 列出所有传感器
- `-s, --sensors <名称>`: 指定传感器
- `-d, --delay <毫秒>`: 采样延迟（默认 1000ms）

**示例：**
```bash
# 列出所有传感器
termux-sensor -l

# 获取加速度计数据
termux-sensor -s "ACCELEROMETER"

# 持续获取数据
termux-sensor -s "ACCELEROMETER" -d 500
```

**返回示例：**
```json
{
  "ACCELEROMETER": {
    "values": [0.1, 9.8, 2.3],
    "timestamp": 1704067200000000000
  }
}
```

---

## 常见传感器名称

- `ACCELEROMETER`: 加速度计
- `GYROSCOPE`: 陀螺仪
- `MAGNETIC_FIELD`: 磁场
- `LIGHT`: 光线传感器
- `PRESSURE`: 气压传感器
- `PROXIMITY`: 距离传感器
- `TEMPERATURE`: 温度传感器
- `GRAVITY`: 重力传感器
- `LINEAR_ACCELERATION`: 线性加速度
- `ROTATION_VECTOR`: 旋转矢量
- `STEP_COUNTER`: 计步器

---

## 使用场景

### 环境检测

```bash
# 检测光线强度
LIGHT=$(termux-sensor -s "LIGHT" -d 100 -n 1 | jq -r '.LIGHT.values[0]')
echo "当前光线: $LIGHT lux"

# 检测是否在口袋里（距离传感器）
PROXIMITY=$(termux-sensor -s "PROXIMITY" -d 100 -n 1 | jq -r '.PROXIMITY.values[0]')
[ "$PROXIMITY" -eq 0 ] && echo "设备在口袋里"
```

### 运动检测

```bash
# 获取加速度数据
ACC=$(termux-sensor -s "ACCELEROMETER" -n 1)
X=$(echo "$ACC" | jq -r '.ACCELEROMETER.values[0]')
Y=$(echo "$ACC" | jq -r '.ACCELEROMETER.values[1]')
Z=$(echo "$ACC" | jq -r '.ACCELEROMETER.values[2]')
echo "加速度: X=$X, Y=$Y, Z=$Z"
```