# 通讯类 API

联系人、短信和电话相关功能。

## 官方来源

- Termux Wiki: https://wiki.termux.com/wiki/Termux:API
- Termux API Package: https://github.com/termux/termux-api-package

## termux-contact-list

获取联系人列表。

**用法：**
```bash
termux-contact-list
```

**返回示例：**
```json
[
  {"name": "张三", "number": "13800138000"},
  {"name": "李四", "number": "13900139000"}
]
```

**权限要求：**
- READ_CONTACTS

---

## termux-sms-list

获取短信列表。

**用法：**
```bash
termux-sms-list [选项]
```

**选项：**
- `-l, --limit <数量>`: 限制返回数量
- `-t, --type <类型>`: 短信类型 (inbox, sent, draft)

**示例：**
```bash
# 获取最近 10 条短信
termux-sms-list -l 10

# 只获取收件箱
termux-sms-list -t inbox
```

**返回示例：**
```json
[
  {
    "number": "10086",
    "received": 1704067200000,
    "body": "您的账户余额为..."
  }
]
```

**权限要求：**
- READ_SMS

---

## termux-sms-send

发送短信。

**用法：**
```bash
termux-sms-send [选项]
```

**选项：**
- `-n, --number <手机号>`: 接收方手机号
- `-m, --message <内容>`: 短信内容

**示例：**
```bash
termux-sms-send -n 13800138000 -m "Hello from Termux"
```

**权限要求：**
- SEND_SMS

---

## termux-telephony-call

拨打电话。

**用法：**
```bash
termux-telephony-call <手机号>
```

**示例：**
```bash
termux-telephony-call 13800138000
```

**注意：**
此命令会直接拨打电话，无需确认。

**权限要求：**
- CALL_PHONE

---

## 使用场景

### 短信转发

```bash
# 获取最新短信并转发
LATEST_SMS=$(termux-sms-list -l 1 -t inbox | jq -r '.[0].body')
termux-sms-send -n 13900139000 -m "$LATEST_SMS"
```

### 联系人查询

```bash
# 查找特定联系人
CONTACT=$(termux-contact-list | jq -r '.[] | select(.name == "张三") | .number')
echo "张三的号码: $CONTACT"
```