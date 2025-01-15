#!/bin/bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

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
    if curl -s "$SCRIPT_URL" -o "$0"; then
        chmod +x "$0"  # 赋予执行权限
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
    if command -v dnf &>/dev/null; then
        dnf autoremove -y
        dnf clean all
        dnf makecache
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v yum &>/dev/null; then
        yum autoremove -y
        yum clean all
        yum makecache
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v apt &>/dev/null; then
        apt autoremove --purge -y
        apt clean -y
        apt autoclean -y
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v apk &>/dev/null; then
        echo "清理包管理器缓存..."
        apk cache clean
        echo "删除系统日志..."
        rm -rf /var/log/*
        echo "删除APK缓存..."
        rm -rf /var/cache/apk/*
        echo "删除临时文件..."
        rm -rf /tmp/*

    elif command -v pacman &>/dev/null; then
        pacman -Rns $(pacman -Qdtq) --noconfirm
        pacman -Scc --noconfirm
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v zypper &>/dev/null; then
        zypper clean --all
        zypper refresh
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v opkg &>/dev/null; then
        echo "删除系统日志..."
        rm -rf /var/log/*
        echo "删除临时文件..."
        rm -rf /tmp/*

    else
        echo -e "${RED}未知的包管理器!${NC}"
        return
    fi
    echo -e "${GREEN}系统清理完成！${NC}"
}

# 设置快捷启动命令
setup_alias() {
    local shell_rc
    if [[ -f ~/.bashrc ]]; then
        shell_rc=~/.bashrc
    elif [[ -f ~/.zshrc ]]; then
        shell_rc=~/.zshrc
    else
        echo -e "${RED}未找到 .bashrc 或 .zshrc 文件，无法设置快捷启动命令。${NC}"
        return
    fi

    if ! grep -q "alias q=" "$shell_rc"; then
        echo "alias q='bash <(curl -s $SCRIPT_URL)'" >> "$shell_rc"
        # 静默重新加载 shell 配置
        source "$shell_rc" >/dev/null 2>&1
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
    else
        echo -e "${RED}未找到 .bashrc 或 .zshrc 文件，无法删除快捷启动命令。${NC}"
        return
    fi

    if grep -q "alias q=" "$shell_rc"; then
        sed -i '/alias q=/d' "$shell_rc"
        echo -e "${GREEN}快捷启动命令 'q' 已删除。${NC}"
    else
        echo -e "${YELLOW}快捷启动命令 'q' 不存在。${NC}"
    fi

    # 删除脚本文件
    if [[ -f "$0" ]]; then
        rm -f "$0"
        echo -e "${GREEN}脚本文件已删除：$0${NC}"
    else
        echo -e "${YELLOW}脚本文件不存在：$0${NC}"
    fi

    # 删除首次运行标记文件
    if [[ -f ~/.vps-script-setup ]]; then
        rm -f ~/.vps-script-setup
        echo -e "${GREEN}首次运行标记文件已删除。${NC}"
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

    # 如果用户输入了有效选项，则等待按回车键继续
    if [[ "$choice" =~ ^[0-5]{1,2}$|^99$ ]]; then
        echo -e "${YELLOW}按回车键继续...${NC}"
        read
    fi
done

# 首次运行脚本时自动设置快捷命令
if [[ ! -f ~/.vps-script-setup ]]; then
    setup_alias
    touch ~/.vps-script-setup  # 标记已设置
fi
