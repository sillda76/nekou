#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # 恢复默认颜色

# 加粗字体
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

# 脚本主标题
echo -e "${CYAN}==============================${NC}"
echo -e "${CYAN}        ${BOLD}DMR直播录制${NORMAL}           ${NC}"
echo -e "${CYAN}==============================${NC}"

# 检测main.py是否在运行
check_dmr() {
    if pgrep -f "python3 /opt/DanmakuRender-5/main.py" > /dev/null; then
        echo -e "${GREEN}${BOLD}DMR状态：正在运行。${NC}${NORMAL}"
    else
        echo -e "${RED}${BOLD}DMR状态：未运行。${NC}${NORMAL}"
    fi
}

# 启动DMR
start_dmr() {
    if pgrep -f "python3 /opt/DanmakuRender-5/main.py" > /dev/null; then
        echo -e "${YELLOW}${BOLD}DMR已经在运行中。${NC}${NORMAL}"
    else
        echo -e "${BLUE}${BOLD}正在启动DMR...${NC}${NORMAL}"
        cd /opt/DanmakuRender-5
        source venv/bin/activate
        nohup python3 main.py > nohup.out 2>&1 &
        echo -e "${GREEN}${BOLD}DMR已启动。${NC}${NORMAL}"
    fi
}

# 停止DMR
stop_dmr() {
    if pgrep -f "python3 /opt/DanmakuRender-5/main.py" > /dev/null; then
        echo -e "${BLUE}${BOLD}正在停止DMR...${NC}${NORMAL}"
        pkill -f "python3 /opt/DanmakuRender-5/main.py"
        echo -e "${GREEN}${BOLD}DMR已停止。${NC}${NORMAL}"
    else
        echo -e "${YELLOW}${BOLD}DMR未运行，无需停止。${NC}${NORMAL}"
    fi
}

# 查看DMR日志
view_log() {
    echo -e "${MAGENTA}${BOLD}查看DMR日志：${NC}${NORMAL}"
    tail -f /opt/DanmakuRender-5/nohup.out
}

# 更新哔哩哔哩cookies
update_cookies() {
    echo -e "${BLUE}${BOLD}正在更新哔哩哔哩cookies...${NC}${NORMAL}"
    cd /opt/DanmakuRender-5/tools
    ./biliup login
    echo -e "${GREEN}${BOLD}cookies更新完成。${NC}${NORMAL}"
}

# 主菜单
while true; do
    echo ""
    check_dmr  # 显示DMR状态
    echo ""
    echo -e "${CYAN}${BOLD}请选择操作：${NC}${NORMAL}"
    echo -e "${CYAN}1. 启动/停止DMR${NC}"
    echo -e "${CYAN}2. 查看DMR日志${NC}"
    echo -e "${CYAN}3. 更新哔哩哔哩cookies${NC}"
    echo -e "${CYAN}0. 退出${NC}"
    read -p "请输入选项（0-3）：" choice

    case $choice in
        1)
            echo -e "${CYAN}1. 启动DMR${NC}"
            echo -e "${CYAN}2. 停止DMR${NC}"
            read -p "请选择（1-2）：" dmr_choice
            if [ "$dmr_choice" == "1" ]; then
                start_dmr
            elif [ "$dmr_choice" == "2" ]; then
                stop_dmr
            else
                echo -e "${RED}${BOLD}无效选项，按任意键返回菜单。${NC}${NORMAL}"
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
            echo -e "${GREEN}${BOLD}退出脚本。${NC}${NORMAL}"
            break
            ;;
        *)
            echo -e "${RED}${BOLD}无效选项，按任意键返回菜单。${NC}${NORMAL}"
            read -n 1 -s
            ;;
    esac
done
