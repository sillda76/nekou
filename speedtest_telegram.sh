#!/bin/bash

# 检查是否已经传递了 Telegram Bot Token 和 Chat ID
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "使用方法: $0 <Telegram Bot Token> <Chat ID>"
  exit 1
fi

# 设置变量
TELEGRAM_BOT_TOKEN="$1"
CHAT_ID="$2"

# 安装必要的工具（如果未安装）
install_dependencies() {
  if ! command -v speedtest-cli &> /dev/null; then
    echo "正在安装 speedtest-cli..."
    sudo apt-get update && sudo apt-get install -y speedtest-cli
  fi

  if ! command -v curl &> /dev/null; then
    echo "正在安装 curl..."
    sudo apt-get install -y curl
  fi

  if ! command -v jq &> /dev/null; then
    echo "正在安装 jq..."
    sudo apt-get install -y jq
  fi
}

# 运行 speedtest 并提取结果
run_speedtest() {
  echo "正在运行 speedtest，请稍等..."
  SPEEDTEST_OUTPUT=$(speedtest-cli --json --share)
  if [ $? -ne 0 ]; then
    echo "错误：speedtest 运行失败！"
    exit 1
  fi

  # 解析 JSON 结果
  DOWNLOAD_SPEED=$(echo "$SPEEDTEST_OUTPUT" | jq -r '.download / 1000000 | round | tostring + " Mbps"')
  UPLOAD_SPEED=$(echo "$SPEEDTEST_OUTPUT" | jq -r '.upload / 1000000 | round | tostring + " Mbps"')
  PING=$(echo "$SPEEDTEST_OUTPUT" | jq -r '.ping | tostring + " ms"')
  IMAGE_URL=$(echo "$SPEEDTEST_OUTPUT" | jq -r '.share')

  if [ -z "$IMAGE_URL" ]; then
    echo "错误：未找到测速结果图片链接！"
    exit 1
  fi
}

# 发送测速结果到 Telegram
send_to_telegram() {
  local MESSAGE="🚀 *测速结果* 🚀
- 📥 下载速度: $DOWNLOAD_SPEED
- 📤 上传速度: $UPLOAD_SPEED
- 🏓 延迟: $PING
- 📷 [查看测速结果图片]($IMAGE_URL)"

  echo "正在发送测速结果到 Telegram..."
  RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$MESSAGE" \
    -d parse_mode="Markdown")

  # 检查发送结果
  if echo "$RESPONSE" | jq -e '.ok' &> /dev/null; then
    echo "✅ 测速结果已发送到 Telegram！"
  else
    echo "❌ 错误：发送测速结果失败！"
    echo "Telegram API 返回: $RESPONSE"
  fi
}

# 主函数
main() {
  install_dependencies
  run_speedtest
  send_to_telegram
}

# 运行主函数
main
