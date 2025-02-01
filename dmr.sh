#!/bin/bash

# 配置变量（方便用户修改）
DMR_DIR="/opt/DanmakuRender-5"
DMR_CMD="python3 main.py"
LOG_FILE="nohup.out"
COOKIES_TOOL_DIR="tools"
COOKIES_TOOL_CMD="./biliup login"

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
    if pgrep -f "$DMR_CMD" > /dev/null; then
        echo -e "${GREEN}${BOLD}DMR状态：正在运行。${NC}${NORMAL}"
    else
        echo -e "${RED}${BOLD}DMR状态：未运行。${NC}${NORMAL}"
    fi
}

# 启动DMR
start_dmr() {
    if pgrep -f "$DMR_CMD" > /dev/null; then
        echo -e "${YELLOW}${BOLD}DMR已经在运行中。${NC}${NORMAL}"
        return 1
    fi
    echo -e "${BLUE}${BOLD}正在启动DMR...${NC}${NORMAL}"
    if cd "$DMR_DIR" || { echo -e "${RED}无法进入DMR目录：$DMR_DIR${NC}"; return 1; }; then
        if ! source venv/bin/activate; then
            echo -e "${RED}激活虚拟环境失败！请检查venv是否存在。${NC}"
            return 1
        fi
        nohup $DMR_CMD > "$LOG_FILE" 2>&1 &
        local pid=$!
        sleep 2
        if ps -p $pid > /dev/null; then
            echo -e "${GREEN}${BOLD}DMR已启动。PID: $pid${NC}${NORMAL}"
        else
            echo -e "${RED}${BOLD}DMR启动失败，请检查日志：$DMR_DIR/$LOG_FILE${NC}${NORMAL}"
        fi
    fi
}

# 停止DMR
stop_dmr() {
    if pgrep -f "$DMR_CMD" > /dev/null; then
        echo -e "${BLUE}${BOLD}正在停止DMR...${NC}${NORMAL}"
        pkill -f "$DMR_CMD"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${BOLD}DMR已停止。${NC}${NORMAL}"
        else
            echo -e "${RED}${BOLD}停止DMR失败，请手动检查进程。${NC}${NORMAL}"
        fi
    else
        echo -e "${YELLOW}${BOLD}DMR未运行，无需停止。${NC}${NORMAL}"
    fi
}

# 查看DMR日志
view_log() {
    echo -e "${MAGENTA}${BOLD}查看DMR日志（按Ctrl+C返回菜单）...${NC}${NORMAL}"
    tail -f "$DMR_DIR/$LOG_FILE"
}

# 更新哔哩哔哩cookies
update_cookies() {
    echo -e "${BLUE}${BOLD}正在更新哔哩哔哩cookies...${NC}${NORMAL}"
    if cd "$DMR_DIR/$COOKIES_TOOL_DIR" || { echo -e "${RED}无法进入工具目录：$DMR_DIR/$COOKIES_TOOL_DIR${NC}"; return 1; }; then
        if [ ! -x "$COOKIES_TOOL_CMD" ]; then
            echo -e "${RED}找不到可执行文件：$COOKIES_TOOL_CMD${NC}"
            return 1
        fi
        $COOKIES_TOOL_CMD || echo -e "${RED}更新cookies失败！${NC}"
    fi
}

# 主菜单
while true; do
    echo ""
    check_dmr  # 显示DMR状态
    echo ""
    echo -e "${CYAN}${BOLD}请选择操作：${NC}${NORMAL}"
    echo -e "${CYAN}1. 启动/重启DMR${NC}"
    echo -e "${CYAN}2. 停止DMR${NC}"
    echo -e "${CYAN}3. 查看DMR日志${NC}"
    echo -e "${CYAN}4. 更新哔哩哔哩cookies${NC}"
    echo -e "${CYAN}0. 退出${NC}"
    read -p "请输入选项（0-4）：" choice

    case $choice in
        1)
            if pgrep -f "$DMR_CMD" > /dev/null; then
                read -p "DMR正在运行，确定要重启吗？(y/n) " restart_choice
                if [[ $restart_choice =~ ^[Yy]$ ]]; then
                    stop_dmr
                    sleep 2
                    start_dmr
                else
                    echo -e "${YELLOW}取消重启操作。${NC}"
                fi
            else
                start_dmr
            fi
            ;;
        2)
            stop_dmr
            ;;
        3)
            view_log
            ;;
        4)
            update_cookies
            ;;
        0)
            echo -e "${GREEN}${BOLD}退出脚本。${NC}${NORMAL}"
            break
            ;;
        *)
            echo -e "${RED}${BOLD}无效选项，请重新输入。${NC}${NORMAL}"
            sleep 1
            ;;
    esac
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
done
