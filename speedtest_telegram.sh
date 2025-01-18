#!/bin/bash

# 检查是否传递了 Telegram Bot Token 和 Chat ID
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "使用方法: $0 <Telegram Bot Token> <Chat ID>"
  exit 1
fi

# 设置变量
TELEGRAM_BOT_TOKEN="$1"
CHAT_ID="$2"
SPEEDTEST_RESULT_FILE="/tmp/speedtest_result.png"

# 安装必要的工具（如果未安装）
if ! command -v speedtest-cli &> /dev/null; then
  echo "正在安装 speedtest-cli..."
  sudo apt-get update && sudo apt-get install -y speedtest-cli
fi

if ! command -v curl &> /dev/null; then
  echo "正在安装 curl..."
  sudo apt-get install -y curl
fi

# 运行 speedtest 并生成图片
echo "正在运行 speedtest..."
speedtest-cli --share > /tmp/speedtest_output.txt

# 提取图片 URL
IMAGE_URL=$(grep -o 'http[s]*://[^ ]*' /tmp/speedtest_output.txt)

# 下载图片
echo "正在下载测速结果图片..."
curl -o "$SPEEDTEST_RESULT_FILE" "$IMAGE_URL"

# 通过 Telegram Bot 发送图片
echo "正在发送图片到 Telegram..."
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
  -F chat_id="$CHAT_ID" \
  -F photo="@$SPEEDTEST_RESULT_FILE"

# 清理临时文件
rm -f "$SPEEDTEST_RESULT_FILE" /tmp/speedtest_output.txt

echo "测速结果已发送到 Telegram！"
