#!/bin/bash

# 设置颜色变量
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # 恢复默认颜色

# 打印欢迎信息
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN} Speedtest to Telegram Bot 一键脚本 ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${YELLOW}本脚本将自动安装依赖、运行Speedtest并将结果发送到Telegram。${NC}"
echo ""

# 检查是否已提供Token和Chat ID
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${BLUE}请输入Telegram Bot Token和Chat ID：${NC}"
    echo -e "${YELLOW}（如果你已经提供了Token和Chat ID，请忽略此步骤）${NC}"
    read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "Telegram Chat ID: " CHAT_ID
else
    TELEGRAM_BOT_TOKEN=$1
    CHAT_ID=$2
fi

# 检查Token和Chat ID是否为空
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo -e "${RED}错误：Telegram Bot Token和Chat ID不能为空！${NC}"
    exit 1
fi

# 安装必要的工具
echo -e "${GREEN}[1/4] 正在更新系统并安装必要的工具...${NC}"
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y speedtest-cli python3-pip > /dev/null 2>&1
pip3 install python-telegram-bot > /dev/null 2>&1

# 运行Speedtest并获取图片URL
echo -e "${GREEN}[2/4] 正在运行Speedtest...${NC}"
SPEEDTEST_RESULT=$(speedtest-cli --share)
IMAGE_URL=$(echo "$SPEEDTEST_RESULT" | grep -o 'http[s]*://[^"]*')

# 检查是否成功获取图片URL
if [ -z "$IMAGE_URL" ]; then
    echo -e "${RED}错误：无法获取Speedtest结果图片URL。请检查网络连接。${NC}"
    exit 1
fi

# 下载图片
echo -e "${GREEN}[3/4] 正在下载Speedtest结果图片...${NC}"
IMAGE_FILE="speedtest_result.png"
curl -o "$IMAGE_FILE" "$IMAGE_URL" > /dev/null 2>&1

# 检查图片文件是否存在且有效
if [ ! -f "$IMAGE_FILE" ]; then
    echo -e "${RED}错误：未找到下载的图片文件。请检查网络连接。${NC}"
    exit 1
fi

if ! file "$IMAGE_FILE" | grep -q "PNG image"; then
    echo -e "${RED}错误：下载的图片文件无效或格式不正确。${NC}"
    exit 1
fi

# 发送图片到Telegram
echo -e "${GREEN}[4/4] 正在发送图片到Telegram...${NC}"
python3 <<END
import os
import asyncio
from telegram import Bot
from telegram.error import TelegramError

async def send_photo():
    try:
        bot = Bot(token="$TELEGRAM_BOT_TOKEN")
        with open("$IMAGE_FILE", 'rb') as file:
            await bot.send_photo(chat_id="$CHAT_ID", photo=file)
            print("图片已成功发送到Telegram！")
    except TelegramError as e:
        print(f"发送图片失败: {e}")
    except Exception as e:
        print(f"发生未知错误: {e}")

asyncio.run(send_photo())
END

# 清理临时文件
echo -e "${GREEN}清理临时文件...${NC}"
rm -f "$IMAGE_FILE"

# 完成提示
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN} 脚本运行完成！Speedtest结果已发送到Telegram。${NC}"
echo -e "${GREEN}==========================================${NC}"
