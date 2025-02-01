#!/bin/bash

# 脚本主标题
echo "=============================="
echo "        DMR直播录制           "
echo "=============================="

# 检测main.py是否在运行
check_dmr() {
    if pgrep -f "/opt/DanmakuRender-5/main.py" > /dev/null; then
        echo "DMR状态：正在运行。"
    else
        echo "DMR状态：未运行。"
    fi
}

# 启动DMR
start_dmr() {
    if pgrep -f "/opt/DanmakuRender-5/main.py" > /dev/null; then
        echo "DMR已经在运行中。"
    else
        echo "正在启动DMR..."
        cd /opt/DanmakuRender-5
        source venv/bin/activate
        nohup python3 main.py &
        echo "DMR已启动。"
    fi
}

# 停止DMR
stop_dmr() {
    if pgrep -f "/opt/DanmakuRender-5/main.py" > /dev/null; then
        echo "正在停止DMR..."
        pkill -f "/opt/DanmakuRender-5/main.py"
        echo "DMR已停止。"
    else
        echo "DMR未运行，无需停止。"
    fi
}

# 查看DMR日志
view_log() {
    echo "查看DMR日志："
    tail -f /opt/DanmakuRender-5/nohup.out
}

# 更新哔哩哔哩cookies
update_cookies() {
    echo "正在更新哔哩哔哩cookies..."
    cd /opt/DanmakuRender-5/tools
    ./biliup login
    echo "cookies更新完成。"
}

# 主菜单
while true; do
    echo ""
    check_dmr  # 显示DMR状态
    echo ""
    echo "请选择操作："
    echo "1. 启动/停止DMR"
    echo "2. 查看DMR日志"
    echo "3. 更新哔哩哔哩cookies"
    echo "0. 退出"
    read -p "请输入选项（0-3）：" choice

    case $choice in
        1)
            echo "1. 启动DMR"
            echo "2. 停止DMR"
            read -p "请选择（1-2）：" dmr_choice
            if [ "$dmr_choice" == "1" ]; then
                start_dmr
            elif [ "$dmr_choice" == "2" ]; then
                stop_dmr
            else
                echo "无效选项，按任意键返回菜单。"
                read -n 1 -s
            fi
            ;;
        2)
            view_log
            ;;
        3)
            update_cookies
            ;;
        0)
            echo "退出脚本。"
            break
            ;;
        *)
            echo "无效选项，按任意键返回菜单。"
            read -n 1 -s
            ;;
    esac
done
