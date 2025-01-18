import os
import requests
import subprocess

# Telegram 配置
TELEGRAM_BOT_TOKEN = "7685027520:AAGewSctXvuXPnyo1essLU8Xtteuva43O3U"
TELEGRAM_CHAT_ID = "-1002426244394"

def send_telegram_message(message):
    """发送消息到 Telegram"""
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {"chat_id": TELEGRAM_CHAT_ID, "text": message}
    requests.post(url, json=payload)

def send_telegram_photo(photo_path):
    """发送图片到 Telegram"""
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendPhoto"
    with open(photo_path, "rb") as photo:
        payload = {"chat_id": TELEGRAM_CHAT_ID}
        files = {"photo": photo}
        requests.post(url, data=payload, files=files)

def run_speedtest():
    """运行 Speedtest 并保存结果为图片"""
    try:
        # 执行 speedtest 并生成共享结果的 URL
        result = subprocess.run(["speedtest", "--share"], capture_output=True, text=True)
        if result.returncode != 0:
            send_telegram_message("Speedtest 运行失败，请检查服务器配置。")
            return None

        # 分析输出，提取共享链接
        output = result.stdout
        for line in output.split("\n"):
            if "http" in line:
                share_url = line.strip()
                break
        else:
            send_telegram_message("未找到 Speedtest 分享链接。")
            return None

        # 下载图片
        image_url = share_url.replace("http://", "https://") + ".png"
        image_path = "/tmp/speedtest_result.png"
        img_response = requests.get(image_url)
        if img_response.status_code == 200:
            with open(image_path, "wb") as img_file:
                img_file.write(img_response.content)
            return image_path
        else:
            send_telegram_message("未能下载 Speedtest 结果图片。")
            return None

    except Exception as e:
        send_telegram_message(f"运行 Speedtest 时发生错误：{e}")
        return None

if __name__ == "__main__":
    send_telegram_message("开始运行 Speedtest...")
    image_path = run_speedtest()
    if image_path:
        send_telegram_photo(image_path)
        send_telegram_message("Speedtest 测试完成，结果已发送。")
    else:
        send_telegram_message("Speedtest 测试失败。")
