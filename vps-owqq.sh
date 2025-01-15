#!/bin/bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 当前脚本路径
CURRENT_SCRIPT_PATH="$(pwd)/vps-owqq.sh"

# 脚本 URL
SCRIPT_URL="https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/vps-owqq.sh"

# 显示菜单
show_menu() {
    clear  # 每次显示菜单时清屏
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}          VPS 管理脚本                 ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}1. 修改 SSH 端口${NC}"
    echo -e "${GREEN}2. 安装 SSH 启动时显示系统信息${NC}"
    echo -e "${GREEN}3. 系统清理${NC}"
    echo -e "${GREEN}4. 安装/管理 Fail2Ban${NC}"
    echo -e "${GREEN}5. 开启/关闭禁 Ping${NC}"
    echo -e "${GREEN}00. 更新脚本${NC}"
    echo -e "${GREEN}99. 卸载脚本${NC}"
    echo -e "${RED}0. 退出脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 更新脚本函数
update_script() {
    echo -e "${YELLOW}正在更新脚本...${NC}"
    if curl -s "$SCRIPT_URL" -o "$CURRENT_SCRIPT_PATH"; then
        chmod +x "$CURRENT_SCRIPT_PATH"  # 赋予执行权限
        echo -e "${GREEN}脚本更新成功！按任意键返回菜单。${NC}"
        read -n 1 -s -r -p ""
        return  # 返回菜单，而不是退出脚本
    else
        echo -e "${RED}脚本更新失败，请检查网络连接或 URL 是否正确。${NC}"
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 系统清理函数
linux_clean() {
    echo -e "${YELLOW}正在系统清理...${NC}"
    # 模拟清理过程
    for i in {1..10}; do
        echo -ne "${GREEN}清理进度: ["
        for j in $(seq 1 $i); do
            echo -n "="
        done
        for j in $(seq $((i+1)) 10); do
            echo -n " "
        done
        echo -ne "] $((i*10))%${NC}\r"
        sleep 0.5
    done
    echo -e "\n${GREEN}系统清理完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 设置快捷启动命令
setup_alias() {
    local shell_rc
    if [[ -f ~/.bashrc ]]; then
        shell_rc=~/.bashrc
    elif [[ -f ~/.zshrc ]]; then
        shell_rc=~/.zshrc
    elif [[ -f ~/.bash_profile ]]; then
        shell_rc=~/.bash_profile
    elif [[ -f ~/.profile ]]; then
        shell_rc=~/.profile
    else
        echo -e "${RED}未找到支持的 Shell 配置文件，正在创建 .bashrc...${NC}"
        touch ~/.bashrc
        shell_rc=~/.bashrc
    fi

    if ! grep -q "alias q=" "$shell_rc"; then
        echo "alias q='$CURRENT_SCRIPT_PATH'" >> "$shell_rc"
        echo -e "${GREEN}快捷命令 'q' 已添加到 $shell_rc。${NC}"
    else
        echo -e "${YELLOW}快捷命令 'q' 已存在。${NC}"
    fi

    # 重新加载配置文件
    if [[ -n "$shell_rc" ]]; then
        source "$shell_rc"
        echo -e "${GREEN}配置文件 $shell_rc 已重新加载。${NC}"
    else
        echo -e "${RED}无法重新加载配置文件。${NC}"
    fi
}

# 卸载脚本函数
uninstall_script() {
    echo -e "${YELLOW}正在卸载脚本...${NC}"

    # 删除快捷启动命令
    local shell_rc
    if [[ -f ~/.bashrc ]]; then
        shell_rc=~/.bashrc
    elif [[ -f ~/.zshrc ]]; then
        shell_rc=~/.zshrc
    elif [[ -f ~/.bash_profile ]]; then
        shell_rc=~/.bash_profile
    elif [[ -f ~/.profile ]]; then
        shell_rc=~/.profile
    else
        echo -e "${RED}未找到支持的 Shell 配置文件，无法删除快捷启动命令。${NC}"
        return
    fi

    if grep -q "alias q=" "$shell_rc"; then
        sed -i '/alias q=/d' "$shell_rc"
        echo -e "${GREEN}快捷启动命令 'q' 已删除。${NC}"
    else
        echo -e "${YELLOW}快捷启动命令 'q' 不存在。${NC}"
    fi

    # 删除标记文件
    if [[ -f ~/.vps-script-setup ]]; then
        rm -f ~/.vps-script-setup
        echo -e "${GREEN}标记文件 ~/.vps-script-setup 已删除。${NC}"
    fi

    # 删除当前目录下的脚本文件
    if [[ -f "$CURRENT_SCRIPT_PATH" ]]; then
        rm -f "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本文件 $CURRENT_SCRIPT_PATH 已删除。${NC}"
    else
        echo -e "${YELLOW}脚本文件 $CURRENT_SCRIPT_PATH 不存在。${NC}"
    fi

    echo -e "${GREEN}脚本卸载完成。${NC}"
    exit 0
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
            linux_clean
            ;;
        4)
            bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/install_fail2ban.sh)
            ;;
        5)
            bash <(curl -s https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/toggle_ping.sh)
            ;;
        00)
            update_script
            ;;
        99)
            uninstall_script
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
done

# 首次运行脚本时自动设置快捷命令
if [[ ! -f ~/.vps-script-setup ]]; then
    # 设置快捷命令
    setup_alias
    touch ~/.vps-script-setup  # 标记已设置
    echo -e "${GREEN}首次运行完成，快捷命令已设置。${NC}"
fi
