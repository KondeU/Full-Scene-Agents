#!/bin/bash

# Termux 应用下载脚本
# 同时下载 Termux 主应用和 Termux API 插件

echo "开始下载 Termux 相关应用..."

# 下载 Termux 主应用
echo "正在下载 Termux 主应用..."
curl -L -o "termux-app_v0.118.3+github-debug_arm64-v8a.apk" \
    "https://gh-proxy.org/https://github.com/termux/termux-app/releases/download/v0.118.3/termux-app_v0.118.3+github-debug_arm64-v8a.apk"

if [ $? -eq 0 ]; then
    echo "✓ Termux 主应用下载完成"
else
    echo "✗ Termux 主应用下载失败"
    exit 1
fi

echo ""

# 下载 Termux API 插件
echo "正在下载 Termux API 插件..."
curl -L -o "termux-api-app_v0.53.0+github.debug.apk" \
    "https://gh-proxy.org/https://github.com/termux/termux-api/releases/download/v0.53.0/termux-api-app_v0.53.0+github.debug.apk"

if [ $? -eq 0 ]; then
    echo "✓ Termux API 插件下载完成"
else
    echo "✗ Termux API 插件下载失败"
    exit 1
fi

echo ""
echo "所有文件下载完成！"
echo "下载的文件："
echo "1. termux-app_v0.118.3+github-debug_arm64-v8a.apk (Termux 主应用)"
echo "2. termux-api-app_v0.53.0+github.debug.apk (Termux API 插件)"