#!/bin/bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 显示菜单
show_menu() {
    clear  # 每次显示菜单时清屏
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}          VPS 管理脚本                 ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}1. 修改 SSH 端口${NC}"
    echo -e "${GREEN}2. 安装 SSH 启动时显示系统信息${NC}"
    echo -e "${GREEN}3. 安装/管理 Fail2Ban${NC}"
    echo -e "${GREEN}4. 开启/关闭禁 Ping${NC}"
    echo -e "${RED}0. 退出脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项数字: " choice

    case $choice in
        1)
            bash <(curl -s https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/ssh_port_chg.sh)
            ;;
        2)
            bash <(curl -s https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/system_info.sh)
            ;;
        3)
            bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/install_fail2ban.sh)
            ;;
        4)
            bash <(curl -s https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/toggle_ping.sh)
            ;;
        0)
            echo -e "${RED}退出脚本。${NC}"
            break
            ;;
        "")
            echo -e "${RED}错误：未输入选项，请按任意键返回菜单。${NC}"
            read -n 1 -s -r -p ""
            ;;
        *)
            echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"
            read -n 1 -s -r -p ""
            ;;
    esac

    # 如果用户输入了有效选项，则等待按回车键继续
    if [[ "$choice" =~ ^[0-4]$ ]]; then
        read -p "按回车键继续..."
    fi
done
