#!/bin/bash

# 配置参数
BOT_TOKEN="7685027520:AAGewSctXvuXPnyo1essLU8Xtteuva43O3U"  # 替换为你的Telegram Bot Token
CHAT_ID="-1002426244394"                                    # 替换为你的Telegram Chat ID

# 安装依赖
echo "正在安装依赖..."
sudo apt-get update
sudo apt-get install -y curl python3 python3-pip
sudo pip3 install pillow requests

# 安装Speedtest CLI
echo "正在安装Speedtest CLI..."
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt-get install -y speedtest

# 运行Speedtest并生成图片
echo "正在运行Speedtest..."
speedtest --accept-license --accept-gdpr -f json > speedtest_result.json

# 读取测速结果
download_speed=$(cat speedtest_result.json | jq -r '.download.bandwidth')
upload_speed=$(cat speedtest_result.json | jq -r '.upload.bandwidth')
ping_latency=$(cat speedtest_result.json | jq -r '.ping.latency')
server_name=$(cat speedtest_result.json | jq -r '.server.name')
server_location=$(cat speedtest_result.json | jq -r '.server.location')

# 转换为Mbps
download_speed_mbps=$(echo "scale=2; $download_speed / 125000" | bc)
upload_speed_mbps=$(echo "scale=2; $upload_speed / 125000" | bc)

# 生成图片
echo "正在生成测速结果图片..."
cat <<EOF > generate_image.py
from PIL import Image, ImageDraw, ImageFont

# 创建图片
img = Image.new('RGB', (600, 400), color=(255, 255, 255))
d = ImageDraw.Draw(img)

# 加载字体
try:
    font = ImageFont.truetype("arial.ttf", 24)
except IOError:
    font = ImageFont.load_default()

# 绘制标题
d.text((50, 20), "SPEEDTEST by OOKLA", font=font, fill=(0, 0, 0))

# 绘制日期和时间
d.text((50, 60), "01/16/2025 @Speedtest 3:51PM GMT", font=font, fill=(0, 0, 0))

# 绘制下载速度
d.text((50, 120), "DOWNLOAD Mbps", font=font, fill=(0, 0, 0))
d.text((50, 150), f"$download_speed_mbps", font=font, fill=(0, 0, 255))

# 绘制上传速度
d.text((50, 200), "UPLOAD Mbps", font=font, fill=(0, 0, 0))
d.text((50, 230), f"$upload_speed_mbps", font=font, fill=(0, 0, 255))

# 绘制Ping
d.text((50, 280), "Ping ms", font=font, fill=(0, 0, 0))
d.text((50, 310), f"$ping_latency", font=font, fill=(0, 0, 255))

# 绘制服务器信息
d.text((50, 360), f"Server: $server_name, $server_location", font=font, fill=(0, 0, 0))

# 保存图片
img.save('speedtest_result.png')
EOF

python3 generate_image.py

# 发送图片到Telegram
echo "正在发送图片到Telegram..."
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto" \
    -F chat_id="$CHAT_ID" \
    -F photo="@speedtest_result.png"

echo "测速结果已发送到Telegram！"
