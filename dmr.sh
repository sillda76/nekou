#!/bin/bash

# 配置变量
DMR_DIR="/opt/DanmakuRender-5"
DMR_CMD="python3 main.py"
LOG_FILE="nohup.out"
COOKIES_TOOL_DIR="tools"
COOKIES_TOOL_CMD="./biliup login"
BILIUP_CMD="./biliup upload"
BILIUP_APPEND_CMD="./biliup append"

# 颜色配置
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# 加粗文本
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

# 显示标题
show_header() {
    clear
    echo -e "${CYAN}==============================${NC}"
    echo -e "${CYAN}        ${BOLD}DMR直播录制控制${NORMAL}        ${NC}"
    echo -e "${CYAN}==============================${NC}"
}

# 检查DMR状态
check_dmr() {
    if pgrep -f "$DMR_CMD" > /dev/null; then
        echo -e "${GREEN}${BOLD}当前状态：DMR正在运行${NC}${NORMAL}"
        return 0
    else
        echo -e "${RED}${BOLD}当前状态：DMR未运行${NC}${NORMAL}"
        return 1
    fi
}

# 启动DMR
start_dmr() {
    if ! cd "$DMR_DIR"; then
        echo -e "${RED}无法进入DMR目录：$DMR_DIR${NC}"
        return 1
    fi
    
    if ! source venv/bin/activate; then
        echo -e "${RED}虚拟环境激活失败！${NC}"
        return 1
    fi
    
    nohup $DMR_CMD > "$LOG_FILE" 2>&1 &
    local pid=$!
    sleep 2
    
    if ps -p $pid > /dev/null; then
        echo -e "${GREEN}DMR启动成功 (PID: $pid)${NC}"
    else
        echo -e "${RED}DMR启动失败，请检查日志${NC}"
    fi
}

# 停止DMR
stop_dmr() {
    pkill -f "$DMR_CMD"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}DMR已成功停止${NC}"
    else
        echo -e "${RED}停止DMR失败，请手动检查${NC}"
    fi
}

# 查看日志
view_log() {
    echo -e "${CYAN}查看日志（按Ctrl+C返回）...${NC}"
    tail -f "$DMR_DIR/$LOG_FILE"
}

# 更新Cookies
update_cookies() {
    if ! cd "$DMR_DIR/$COOKIES_TOOL_DIR"; then
        echo -e "${RED}无法进入工具目录${NC}"
        return 1
    fi
    
    if [ ! -x "${COOKIES_TOOL_CMD%% *}" ]; then
        echo -e "${RED}找不到可执行文件${NC}"
        return 1
    fi
    
    $COOKIES_TOOL_CMD || echo -e "${RED}Cookie更新失败${NC}"
}

# biliup快速上传
biliup_upload() {
    if ! cd "$DMR_DIR/$COOKIES_TOOL_DIR"; then
        echo -e "${RED}无法进入工具目录${NC}"
        return 1
    fi
    
    if [ ! -x "${BILIUP_CMD%% *}" ]; then
        echo -e "${RED}找不到biliup可执行文件${NC}"
        return 1
    fi
    
    read -p "请输入视频目录路径: " video_path
    if [ ! -d "$video_path" ]; then
        echo -e "${RED}视频目录不存在，请检查路径${NC}"
        return 1
    fi
    
    read -p "请输入视频分区tid（例如：17为单机游戏）: " tid
    if ! [[ "$tid" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}分区tid必须为数字${NC}"
        return 1
    fi
    
    read -p "请输入视频标签（多个标签用逗号分隔）: " tags
    if [ -z "$tags" ]; then
        echo -e "${RED}标签不能为空${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在上传视频...${NC}"
    $BILIUP_CMD "$video_path" --tid "$tid" --tag "$tags"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}视频上传成功${NC}"
    else
        echo -e "${RED}视频上传失败，请检查日志${NC}"
    fi
}

# biliup视频追加上传
biliup_append() {
    if ! cd "$DMR_DIR/$COOKIES_TOOL_DIR"; then
        echo -e "${RED}无法进入工具目录${NC}"
        return 1
    fi
    
    if [ ! -x "${BILIUP_APPEND_CMD%% *}" ]; then
        echo -e "${RED}找不到biliup可执行文件${NC}"
        return 1
    fi
    
    read -p "请输入要追加的视频BV号: " vid
    if [[ ! "$vid" =~ ^BV ]]; then
        echo -e "${RED}BV号格式错误，应以BV开头${NC}"
        return 1
    fi
    
    video_paths=()
    while true; do
        read -p "请输入要追加的视频路径: " path
        if [ ! -f "$path" ]; then
            echo -e "${RED}文件不存在，请检查路径${NC}"
            continue
        fi
        video_paths+=("$path")
        
        read -p "是否还有更多视频需要追加？(y/n): " more
        if [[ ! "$more" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    if [ ${#video_paths[@]} -eq 0 ]; then
        echo -e "${RED}未提供任何视频路径${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在追加上传视频...${NC}"
    $BILIUP_APPEND_CMD --vid "$vid" "${video_paths[@]}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}视频追加上传成功${NC}"
    else
        echo -e "${RED}视频追加上传失败，请检查日志${NC}"
    fi
}

# 主界面
main_menu() {
    while true; do
        show_header
        check_dmr
        echo ""
        echo -e "${CYAN}${BOLD}请选择操作：${NC}${NORMAL}"
        echo -e "${CYAN}1. 启动/停止DMR服务${NC}"
        echo -e "${CYAN}2. 查看实时日志${NC}"
        echo -e "${CYAN}3. 更新哔哩哔哩Cookies${NC}"
        echo -e "${CYAN}4. biliup快速上传${NC}"
        echo -e "${CYAN}5. biliup视频追加上传${NC}"
        echo -e "${CYAN}0. 退出程序${NC}"
        echo ""
        
        read -p "请输入选项（0-5）：" choice
        case $choice in
            1)
                show_header
                if check_dmr; then
                    read -p "DMR正在运行，是否要停止？(y/n) " confirm
                    if [[ $confirm =~ ^[Yy]$ ]]; then
                        stop_dmr
                    else
                        echo -e "${YELLOW}取消停止操作${NC}"
                    fi
                else
                    echo -e "${BLUE}正在尝试启动DMR...${NC}"
                    start_dmr
                fi
                read -n 1 -s -r -p "操作已完成，按任意键返回..."
                ;;

            2)
                show_header
                view_log
                ;;

            3)
                show_header
                update_cookies
                read -n 1 -s -r -p "操作已完成，按任意键返回..."
                ;;

            4)
                show_header
                biliup_upload
                read -n 1 -s -r -p "操作已完成，按任意键返回..."
                ;;

            5)
                show_header
                biliup_append
                read -n 1 -s -r -p "操作已完成，按任意键返回..."
                ;;

            0)
                exit 0
                ;;

            *)
                echo -e "${RED}无效选项，请重新输入！${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主程序
main_menu
