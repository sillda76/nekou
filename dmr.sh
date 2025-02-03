#!/bin/bash

# 配置变量
DMR_DIR="/opt/DanmakuRender-5"
DMR_CMD="python3 main.py"
LOG_FILE="nohup.out"
COOKIES_TOOL_DIR="tools"
COOKIES_TOOL_CMD="./biliup login"
BILIUP_CMD="./biliup upload"
BILIUP_APPEND_CMD="./biliup append"
GIT_REPO="https://github.com/sillda76/DanmakuRender.git"
GIT_BRANCH="v5"

# 颜色配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    if [ ! -d "$DMR_DIR" ]; then
        echo -e "${YELLOW}${BOLD}当前状态：DanmakuRender V5 未安装${NC}${NORMAL}"
        return 2
    fi

    if pgrep -f "$DMR_CMD" > /dev/null; then
        echo -e "${GREEN}${BOLD}当前状态：DMR正在运行${NC}${NORMAL}"
        return 0
    else
        echo -e "${RED}${BOLD}当前状态：DMR未运行${NC}${NORMAL}"
        return 1
    fi
}

# 安装DanmakuRender V5
install_dmr() {
    if [ -d "$DMR_DIR" ]; then
        echo -e "${YELLOW}DanmakuRender-5 已存在于 $DMR_DIR，请先卸载后再安装。${NC}"
        return 1
    fi

    # 确保git已经安装
    echo -e "${BLUE}检查/安装 git...${NC}"
    if ! command -v git &> /dev/null; then
        if ! sudo apt update; then
            echo -e "${RED}更新软件包列表失败！${NC}"
            return 1
        fi
        if ! sudo apt install -y git; then
            echo -e "${RED}安装 git 失败！${NC}"
            return 1
        fi
    fi

    echo -e "${BLUE}正在从 GitHub 拉取 DanmakuRender V5...${NC}"
    if ! git clone -b "$GIT_BRANCH" "$GIT_REPO" "$DMR_DIR"; then
        echo -e "${RED}拉取 DanmakuRender V5 失败，请检查网络或仓库地址。${NC}"
        return 1
    fi

    echo -e "${BLUE}正在安装 python3-venv 并创建虚拟环境...${NC}"
    if ! sudo apt update; then
        echo -e "${RED}更新软件包列表失败！${NC}"
        return 1
    fi
    if ! sudo apt install -y python3-venv; then
        echo -e "${RED}安装 python3-venv 失败！${NC}"
        return 1
    fi

    if ! cd "$DMR_DIR"; then
        echo -e "${RED}无法进入 DMR 目录：$DMR_DIR${NC}"
        return 1
    fi

    if ! python3 -m venv venv; then
        echo -e "${RED}虚拟环境创建失败！${NC}"
        return 1
    fi

    echo -e "${BLUE}正在激活虚拟环境和安装依赖...${NC}"
    if ! source venv/bin/activate; then
        echo -e "${RED}虚拟环境激活失败！${NC}"
        return 1
    fi

    if ! pip install -r requirements.txt; then
        echo -e "${RED}依赖安装失败！${NC}"
        return 1
    fi

    echo -e "${GREEN}DanmakuRender V5 安装成功！虚拟环境已创建并依赖已安装。${NC}"
}

# 卸载DanmakuRender V5
uninstall_dmr() {
    if [ ! -d "$DMR_DIR" ]; then
        echo -e "${YELLOW}DanmakuRender-5 未安装，无需卸载。${NC}"
        return 0
    fi

    echo -e "${BLUE}正在卸载 DanmakuRender V5...${NC}"
    if rm -rf "$DMR_DIR"; then
        echo -e "${GREEN}DanmakuRender V5 卸载成功！${NC}"
    else
        echo -e "${RED}卸载失败，请检查权限或手动删除 $DMR_DIR。${NC}"
    fi
}

# 安装微软雅黑字体和Emoji
install_fonts() {
    echo -e "${BLUE}正在更新软件包列表...${NC}"
    if ! sudo apt update; then
        echo -e "${RED}更新软件包列表失败！${NC}"
        return 1
    fi

    echo -e "${BLUE}确保 fontconfig 已经安装...${NC}"
    if ! sudo apt install -y fontconfig; then
        echo -e "${RED}安装 fontconfig 失败！${NC}"
        return 1
    fi

    echo -e "${BLUE}正在安装 Emoji 字体...${NC}"
    if ! sudo apt install -y fonts-symbola fonts-noto-color-emoji; then
        echo -e "${RED}安装 Emoji 字体失败！${NC}"
        return 1
    fi

    echo -e "${BLUE}正在从 GitHub 下载 微软雅黑 字体...${NC}"
    if ! wget -O "微软雅黑.ttf" "https://github.com/sillda76/vps-scripts/raw/main/微软雅黑.ttf"; then
        echo -e "${RED}下载 微软雅黑 字体失败！${NC}"
        return 1
    fi

    echo -e "${BLUE}正在安装 微软雅黑 字体...${NC}"
    sudo mkdir -p /usr/share/fonts/truetype/microsoft/
    sudo mv "微软雅黑.ttf" /usr/share/fonts/truetype/microsoft/
    sudo fc-cache -fv

    echo -e "${GREEN}微软雅黑字体和Emoji安装成功！${NC}"
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
    echo -e "${CYAN}查看日志（按Ctrl+C返回菜单）...${NC}"
    trap 'echo -e "\n${CYAN}返回菜单...${NC}"; sleep 1; return' SIGINT
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

# 一键删除回放/渲染视频
delete_replays() {
    if [ ! -d "$DMR_DIR" ]; then
        echo -e "${YELLOW}DanmakuRender-5 未安装，无需删除回放视频。${NC}"
        return 0
    fi

    echo -e "${BLUE}正在删除回放/渲染视频...${NC}"
    replay_dir1="$DMR_DIR/直播回放"
    replay_dir2="$DMR_DIR/直播回放（弹幕版）"

    if [ -d "$replay_dir1" ]; then
        rm -rf "$replay_dir1"
        echo -e "${GREEN}已删除：$replay_dir1${NC}"
    else
        echo -e "${YELLOW}未找到：$replay_dir1${NC}"
    fi

    if [ -d "$replay_dir2" ]; then
        rm -rf "$replay_dir2"
        echo -e "${GREEN}已删除：$replay_dir2${NC}"
    else
        echo -e "${YELLOW}未找到：$replay_dir2${NC}"
    fi
}

# 主界面
main_menu() {
    while true; do
        show_header
        check_dmr
        echo ""
        echo -e "${CYAN}${BOLD}请选择操作：${NC}${NORMAL}"
        echo -e "${CYAN}1. 安装 DanmakuRender V5${NC}"
        echo -e "${CYAN}2. 启动/停止 DMR 服务${NC}"
        echo -e "${CYAN}3. 查看实时日志${NC}"
        echo -e "${CYAN}4. 一键删除回放/渲染视频${NC}"
        echo -e "${CYAN}5. 更新哔哩哔哩 Cookies${NC}"
        echo -e "${CYAN}6. biliup 快速上传${NC}"
        echo -e "${CYAN}7. biliup 视频追加上传${NC}"
        echo -e "${CYAN}8. 安装微软雅黑字体和Emoji${NC}"
        echo -e "${CYAN}9. 卸载 DanmakuRender V5${NC}"
        echo -e "${CYAN}0. 退出程序${NC}"
        echo ""

        read -p "请输入选项（0-9）：" choice
        case $choice in
            1)
                show_header
                install_dmr
                ;;
            2)
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
                ;;
            3)
                show_header
                view_log
                ;;
            4)
                show_header
                delete_replays
                ;;
            5)
                show_header
                update_cookies
                ;;
            6)
                show_header
                biliup_upload
                ;;
            7)
                show_header
                biliup_append
                ;;
            8)
                show_header
                install_fonts
                ;;
            9)
                show_header
                uninstall_dmr
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入！${NC}"
                sleep 1
                continue
                ;;
        esac

        # 统一提示按任意键返回菜单
        read -n 1 -s -r -p "按任意键返回菜单..."
    done
}

# 启动主程序
main_menu
