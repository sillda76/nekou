#!/bin/bash

# 定义颜色变量（加粗）
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
ORANGE='\033[1;38;5;208m'
MAGENTA='\033[1;35m'
LIGHT_BLUE='\033[1;34m'
LIGHT_GREEN='\033[1;32m'
LIGHT_RED='\033[1;31m'
NC='\033[0m' # 恢复默认颜色

# 当前脚本路径
CURRENT_SCRIPT_PATH="$(pwd)/vps-owqq.sh"

# 脚本 URL
SCRIPT_URL="https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/vps-owqq.sh"

# 显示菜单
show_menu() {
    clear  # 每次显示菜单时清屏
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${GREEN}VPS Manager${NC}"
    echo -e "${BLUE}https://github.com/sillda76/vps-scripts${NC}"
    echo -e "${PURPLE}========================================${NC}"
    # 显示菜单选项（加粗）
    echo -e "${YELLOW}1. 修改 SSH 端口${NC}"
    echo -e "${CYAN}2. 系统更新${NC}"
    echo -e "${PURPLE}3. 系统清理${NC}"
    echo -e "${ORANGE}4. 管理 Fail2Ban${NC}"
    echo -e "${MAGENTA}5. 禁 Ping 设置${NC}"
    echo -e "${LIGHT_BLUE}6. SSH 系统信息${NC}"
    echo -e "${LIGHT_GREEN}00. 更新脚本${NC}"
    echo -e "${LIGHT_RED}99. 卸载脚本${NC}"
    echo -e "${RED}0. 退出脚本${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# 更新脚本函数
update_script() {
    echo -e "${YELLOW}正在更新脚本...${NC}"
    if curl -s "$SCRIPT_URL" -o "$CURRENT_SCRIPT_PATH"; then
        chmod +x "$CURRENT_SCRIPT_PATH"  # 赋予执行权限
        echo -e "${GREEN}脚本更新成功！按任意键返回菜单。${NC}"
        read -n 1 -s -r -p ""
        # 重新运行脚本
        exec "$CURRENT_SCRIPT_PATH"
    else
        echo -e "${RED}脚本更新失败，请检查网络连接或 URL 是否正确。${NC}"
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 系统更新函数
system_update() {
    echo -e "${YELLOW}正在系统更新...${NC}"

    if command -v apt &>/dev/null; then
        echo -e "${YELLOW}使用 APT 包管理器进行系统更新...${NC}"
        echo -e "${YELLOW}更新软件包列表...${NC}"
        apt update -y
        echo -e "${YELLOW}升级已安装的软件包...${NC}"
        apt upgrade -y
        echo -e "${YELLOW}升级系统版本...${NC}"
        apt dist-upgrade -y
        echo -e "${YELLOW}清理不再需要的包...${NC}"
        apt autoremove -y
    elif command -v yum &>/dev/null; then
        echo -e "${YELLOW}使用 YUM 包管理器进行系统更新...${NC}"
        echo -e "${YELLOW}更新软件包...${NC}"
        yum update -y
        echo -e "${YELLOW}升级系统...${NC}"
        yum upgrade -y
    elif command -v dnf &>/dev/null; then
        echo -e "${YELLOW}使用 DNF 包管理器进行系统更新...${NC}"
        echo -e "${YELLOW}更新软件包...${NC}"
        dnf update -y
        echo -e "${YELLOW}升级系统...${NC}"
        dnf upgrade -y
    elif command -v pacman &>/dev/null; then
        echo -e "${YELLOW}使用 Pacman 包管理器进行系统更新...${NC}"
        echo -e "${YELLOW}同步软件包数据库并升级系统...${NC}"
        pacman -Syu --noconfirm
    elif command -v zypper &>/dev/null; then
        echo -e "${YELLOW}使用 Zypper 包管理器进行系统更新...${NC}"
        echo -e "${YELLOW}刷新软件包列表...${NC}"
        zypper refresh
        echo -e "${YELLOW}更新软件包...${NC}"
        zypper update -y
    elif command -v apk &>/dev/null; then
        echo -e "${YELLOW}使用 APK 包管理器进行系统更新...${NC}"
        echo -e "${YELLOW}更新软件包列表...${NC}"
        apk update
        echo -e "${YELLOW}升级已安装的软件包...${NC}"
        apk upgrade
    else
        echo -e "${RED}未知的包管理器，无法执行系统更新。${NC}"
    fi
    echo -e "${GREEN}系统更新完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 系统清理函数
linux_clean() {
    echo -e "${YELLOW}正在系统清理...${NC}"

    # 清理步骤
    steps=(
        "清理包管理器缓存..."
        "删除系统日志..."
        "删除临时文件..."
        "清理 APK 缓存..."
        "清理 YUM/DNF 缓存..."
        "清理 APT 缓存..."
        "清理 Pacman 缓存..."
        "清理 Zypper 缓存..."
        "清理 Opkg 缓存..."
    )

    # 总步骤数
    total_steps=${#steps[@]}

    # 显示清理内容
    echo -e "${YELLOW}本次清理将执行以下操作：${NC}"
    for step in "${steps[@]}"; do
        echo -e "  - ${step}"
    done
    echo -e "${YELLOW}开始清理...${NC}"

    # 初始化进度条
    echo -e "\n\n"  # 为进度条预留空间
    for ((i = 0; i < total_steps; i++)); do
        # 显示当前清理步骤
        echo -e "${YELLOW}${steps[$i]}${NC}"

        # 执行清理操作
        case ${steps[$i]} in
            "清理包管理器缓存...")
                if command -v dnf &>/dev/null; then
                    dnf clean all
                elif command -v yum &>/dev/null; then
                    yum clean all
                elif command -v apt &>/dev/null; then
                    apt clean -y
                    apt autoclean -y
                elif command -v apk &>/dev/null; then
                    apk cache clean
                elif command -v pacman &>/dev/null; then
                    pacman -Scc --noconfirm
                elif command -v zypper &>/dev/null; then
                    zypper clean --all
                elif command -v opkg &>/dev/null; then
                    opkg clean
                fi
                ;;
            "删除系统日志...")
                journalctl --rotate
                journalctl --vacuum-time=1s
                journalctl --vacuum-size=500M
                ;;
            "删除临时文件...")
                rm -rf /tmp/*
                rm -rf /var/tmp/*
                ;;
            "清理 APK 缓存...")
                if command -v apk &>/dev/null; then
                    apk cache clean
                fi
                ;;
            "清理 YUM/DNF 缓存...")
                if command -v dnf &>/dev/null; then
                    dnf clean all
                elif command -v yum &>/dev/null; then
                    yum clean all
                fi
                ;;
            "清理 APT 缓存...")
                if command -v apt &>/dev/null; then
                    apt clean -y
                    apt autoclean -y
                fi
                ;;
            "清理 Pacman 缓存...")
                if command -v pacman &>/dev/null; then
                    pacman -Scc --noconfirm
                fi
                ;;
            "清理 Zypper 缓存...")
                if command -v zypper &>/dev/null; then
                    zypper clean --all
                fi
                ;;
            "清理 Opkg 缓存...")
                if command -v opkg &>/dev/null; then
                    opkg clean
                fi
                ;;
        esac

        # 更新进度条
        progress=$(( (i + 1) * 100 / total_steps ))
        tput sc  # 保存光标位置
        tput cup $(tput lines) 0  # 将光标移动到屏幕底部
        echo -ne "${GREEN}清理进度: ["
        for ((j = 0; j < progress / 2; j++)); do
            echo -n "="
        done
        for ((j = progress / 2; j < 50; j++)); do
            echo -n " "
        done
        echo -ne "] ${progress}%${NC}"
        tput rc  # 恢复光标位置

        # 模拟清理时间
        sleep 1
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
            system_update
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
        6)
            bash <(curl -s https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/system_info.sh)
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
