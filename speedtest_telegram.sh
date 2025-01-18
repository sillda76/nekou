#!/bin/bash

# 检查是否传递了 Telegram Bot Token 和 Chat ID
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "使用方法: $0 <Telegram Bot Token> <Chat ID>"
  exit 1
fi

# 设置变量
TELEGRAM_BOT_TOKEN="$1"
CHAT_ID="$2"
SPEEDTEST_RESULT_FILE="speedtest_result_$(date +%Y%m%d_%H%M%S).png"  # 图片保存到当前目录，文件名带时间戳

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

if [ -z "$IMAGE_URL" ]; then
  echo "错误：未找到测速结果图片 URL！"
  exit 1
fi

# 下载图片到当前目录
echo "正在下载测速结果图片到当前目录: $SPEEDTEST_RESULT_FILE..."
curl -o "$SPEEDTEST_RESULT_FILE" "$IMAGE_URL"

# 检查图片文件是否下载成功
if [ ! -f "$SPEEDTEST_RESULT_FILE" ]; then
  echo "错误：图片文件未下载成功！"
  exit 1
else
  echo "图片已保存到: $(pwd)/$SPEEDTEST_RESULT_FILE"
fi

# 通过 Telegram Bot 发送图片
echo "正在发送图片到 Telegram..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
  -F chat_id="$CHAT_ID" \
  -F photo="@$SPEEDTEST_RESULT_FILE")

# 检查发送结果
if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "测速结果已发送到 Telegram！"
else
  echo "错误：发送图片失败！"
  echo "Telegram API 返回: $RESPONSE"
fi

# 清理临时文件（仅清理 speedtest 输出文件）
rm -f /tmp/speedtest_output.txt
