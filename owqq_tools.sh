#!/bin/bash
# 定义美观显示的颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# 当前脚本路径及远程脚本 URL（用于更新）
CURRENT_SCRIPT_PATH="$(pwd)/owqq_tools.sh"
SCRIPT_URL="https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/owqq_tools.sh"

# SSH美化内容
BEAUTIFY_CONTENT='
# 命令行美化
parse_git_branch() {
    git branch 2> /dev/null | sed -e '\''/^[^*]/d'\'' -e '\''s/* \(.*\)/ (\1)/'\''
}
PS1='\''\[\033[01;38;5;117m\]\u\[\033[01;33m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[01;35m\]$(parse_git_branch)\[\033[00m\] \[\033[01;36m\][\D{%H:%M:%S}]\[\033[00m\]\n\[\033[01;37m\]\$ \[\033[00m\]'\''
# 命令行美化结束
'

# 设置快捷启动命令 alias（首次自动设置）
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
        touch ~/.bashrc
        shell_rc=~/.bashrc
    fi
    if ! grep -q "alias q=" "$shell_rc"; then
        echo "alias q='${CURRENT_SCRIPT_PATH}'" >> "$shell_rc"
    fi
    source "$shell_rc" >/dev/null 2>&1
}

setup_alias

# 检测网络栈类型
detect_network_stack() {
    local has_ipv4=0
    local has_ipv6=0

    # 检查IPv4
    if ip -4 route get 8.8.8.8 &>/dev/null; then
        has_ipv4=1
    fi

    # 检查IPv6
    if ip -6 route get 2001:4860:4860::8888 &>/dev/null; then
        has_ipv6=1
    fi

    if [ $has_ipv4 -eq 1 ] && [ $has_ipv6 -eq 1 ]; then
        echo "dual"
    elif [ $has_ipv4 -eq 1 ]; then
        echo "ipv4"
    elif [ $has_ipv6 -eq 1 ]; then
        echo "ipv6"
    else
        echo "none"
    fi
}

# 修改 DNS 配置
modify_dns() {
    clear
    echo -e "${CYAN}当前DNS配置如下：${NC}"
    cat /etc/resolv.conf
    echo -e "${CYAN}----------------------------------------${NC}"
    
    # 检测当前网络栈
    local network_stack=$(detect_network_stack)
    case $network_stack in
        "dual") echo -e "${GREEN}检测到双栈网络 (IPv4+IPv6)${NC}" ;;
        "ipv4") echo -e "${GREEN}检测到IPv4单栈网络${NC}" ;;
        "ipv6") echo -e "${GREEN}检测到IPv6单栈网络${NC}" ;;
        *) echo -e "${RED}未检测到有效网络连接${NC}"; 
           read -n 1 -s -r -p "按任意键返回菜单..."
           return 1 ;;
    esac

    echo -e "${YELLOW}[DNS配置] 请选择 DNS 优化方案：${NC}"
    echo -e "${YELLOW}1. 国外DNS优化: v4: 1.1.1.1 8.8.8.8, v6: 2606:4700:4700::1111 2001:4860:4860::8888${NC}"
    echo -e "${YELLOW}2. 国内DNS优化: v4: 223.5.5.5 183.60.83.19, v6: 2400:3200::1 2400:da00::6666${NC}"
    echo -e "${YELLOW}3. 手动编辑DNS配置${NC}"
    echo -e "${YELLOW}4. 保持默认${NC}"
    read -p "请输入选项数字: " dns_choice

    # 准备DNS配置
    local dns_config=""
    case $dns_choice in
        1) # 国外DNS
            if [[ $network_stack == "ipv4" || $network_stack == "dual" ]]; then
                dns_config+="nameserver 1.1.1.1\nnameserver 8.8.8.8\n"
            fi
            if [[ $network_stack == "ipv6" || $network_stack == "dual" ]]; then
                dns_config+="nameserver 2606:4700:4700::1111\nnameserver 2001:4860:4860::8888\n"
            fi
            ;;
        2) # 国内DNS
            if [[ $network_stack == "ipv4" || $network_stack == "dual" ]]; then
                dns_config+="nameserver 223.5.5.5\nnameserver 183.60.83.19\n"
            fi
            if [[ $network_stack == "ipv6" || $network_stack == "dual" ]]; then
                dns_config+="nameserver 2400:3200::1\nnameserver 2400:da00::6666\n"
            fi
            ;;
        3) # 手动编辑
            echo -e "${YELLOW}正在解锁 /etc/resolv.conf 文件...${NC}"
            sudo chattr -i /etc/resolv.conf 2>/dev/null
            echo -e "${YELLOW}正在禁用 systemd-resolved...${NC}"
            sudo systemctl disable --now systemd-resolved 2>/dev/null
            echo -e "${YELLOW}请使用 nano 编辑 /etc/resolv.conf，修改DNS配置后保存退出。${NC}"
            sudo nano /etc/resolv.conf
            sudo chattr +i /etc/resolv.conf 2>/dev/null
            echo -e "${GREEN}DNS配置已更新并锁定。${NC}"
            echo -e "${CYAN}新的DNS配置如下：${NC}"
            cat /etc/resolv.conf
            read -n 1 -s -r -p "按任意键返回菜单..."
            return
            ;;
        4) # 保持默认
            echo -e "${GREEN}保持默认DNS配置，未做任何修改。${NC}"
            read -n 1 -s -r -p "按任意键返回菜单..."
            return
            ;;
        *)
            echo -e "${RED}错误：无效选项。${NC}"
            read -n 1 -s -r -p "按任意键返回菜单..."
            return
            ;;
    esac

    # 应用DNS配置
    echo -e "${YELLOW}正在解锁 /etc/resolv.conf 文件...${NC}"
    sudo chattr -i /etc/resolv.conf 2>/dev/null
    echo -e "${YELLOW}正在禁用 systemd-resolved...${NC}"
    sudo systemctl disable --now systemd-resolved 2>/dev/null
    echo -e "${YELLOW}写入DNS配置...${NC}"
    
    # 备份原有配置
    sudo cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    
    # 写入新配置
    echo -e "$dns_config" | sudo tee /etc/resolv.conf >/dev/null
    sudo chattr +i /etc/resolv.conf 2>/dev/null
    
    echo -e "${GREEN}DNS优化已完成。新的DNS配置如下：${NC}"
    cat /etc/resolv.conf
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# SSH命令行美化
ssh_beautify() {
    clear
    echo -e "${YELLOW}SSH命令行美化选项:${NC}"
    echo -e "1. 安装命令行美化"
    echo -e "2. 卸载命令行美化"
    echo -e "3. 返回主菜单"
    read -p "请输入选项 (1/2/3): " choice

    case $choice in
        1)
            # 检查是否已存在美化内容
            if grep -q "# 命令行美化" ~/.bashrc; then
                echo -e "${YELLOW}命令行美化已经安装过了。${NC}"
            else
                echo "$BEAUTIFY_CONTENT" >> ~/.bashrc
                echo -e "${GREEN}命令行美化已安装，请重新打开终端或运行 'source ~/.bashrc' 查看效果。${NC}"
            fi
            read -n 1 -s -r -p "按任意键返回菜单..."
            ;;
        2)
            # 删除美化内容
            if grep -q "# 命令行美化" ~/.bashrc; then
                # 使用sed删除从"# 命令行美化"到"# 命令行美化结束"之间的内容
                sed -i '/# 命令行美化/,/# 命令行美化结束/d' ~/.bashrc
                echo -e "${GREEN}命令行美化已卸载，请重新打开终端或运行 'source ~/.bashrc' 查看效果。${NC}"
            else
                echo -e "${YELLOW}没有找到已安装的命令行美化内容。${NC}"
            fi
            read -n 1 -s -r -p "按任意键返回菜单..."
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}无效的选项。${NC}"
            read -n 1 -s -r -p "按任意键返回菜单..."
            ;;
    esac
}

# 通用安装包管理器函数
install_package() {
    local package=$1
    if command -v apt &>/dev/null; then
        apt install -y "$package"
    elif command -v yum &>/dev/null; then
        yum install -y "$package"
    elif command -v dnf &>/dev/null; then
        dnf install -y "$package"
    elif command -v pacman &>/dev/null; then
        pacman -S --noconfirm "$package"
    elif command -v zypper &>/dev/null; then
        zypper install -y "$package"
    elif command -v apk &>/dev/null; then
        apk add --no-cache "$package"
    else
        echo -e "${RED}未知的包管理器，无法安装 ${package}。${NC}"
        return 1
    fi
}

# 系统更新
system_update() {
    echo -e "${YELLOW}正在系统更新...${NC}"
    if command -v apt &>/dev/null; then
        apt update -y && apt upgrade -y && apt dist-upgrade -y && apt autoremove -y
    elif command -v yum &>/dev/null; then
        yum update -y && yum upgrade -y
    elif command -v dnf &>/dev/null; then
        dnf update -y && dnf upgrade -y
    elif command -v pacman &>/dev/null; then
        pacman -Syu --noconfirm
    elif command -v zypper &>/dev/null; then
        zypper refresh && zypper update -y
    elif command -v apk &>/dev/null; then
        apk update && apk upgrade
    else
        echo -e "${RED}未知的包管理器，无法执行系统更新。${NC}"
    fi
    echo -e "${GREEN}系统更新完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 系统清理
system_clean() {
    echo -e "${YELLOW}正在系统清理...${NC}"
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
    total_steps=${#steps[@]}
    echo -e "${YELLOW}本次清理将执行以下操作：${NC}"
    for step in "${steps[@]}"; do
        echo -e "  - ${step}"
    done
    echo -e "${YELLOW}开始清理...${NC}"
    for ((i = 0; i < total_steps; i++)); do
        echo -e "${YELLOW}${steps[$i]}${NC}"
        case ${steps[$i]} in
            "清理包管理器缓存...")
                if command -v dnf &>/dev/null; then
                    dnf clean all
                elif command -v yum &>/dev/null; then
                    yum clean all
                elif command -v apt &>/dev/null; then
                    apt clean && apt autoclean
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
                [ -x "$(command -v apk)" ] && apk cache clean
                ;;
            "清理 YUM/DNF 缓存...")
                if command -v dnf &>/dev/null; then
                    dnf clean all
                elif command -v yum &>/dev/null; then
                    yum clean all
                fi
                ;;
            "清理 APT 缓存...")
                [ -x "$(command -v apt)" ] && { apt clean; apt autoclean; }
                ;;
            "清理 Pacman 缓存...")
                [ -x "$(command -v pacman)" ] && pacman -Scc --noconfirm
                ;;
            "清理 Zypper 缓存...")
                [ -x "$(command -v zypper)" ] && zypper clean --all
                ;;
            "清理 Opkg 缓存...")
                [ -x "$(command -v opkg)" ] && opkg clean
                ;;
        esac
    done
    echo -e "\n${GREEN}系统清理完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 更新脚本
update_script() {
    echo -e "${YELLOW}正在更新脚本...${NC}"
    if curl -s "$SCRIPT_URL" -o "$CURRENT_SCRIPT_PATH"; then
        chmod +x "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本更新成功！按任意键返回菜单。${NC}"
        read -n 1 -s -r -p ""
        exec "$CURRENT_SCRIPT_PATH"
    else
        echo -e "${RED}脚本更新失败，请检查网络连接或 URL 是否正确。${NC}"
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 卸载脚本
uninstall_script() {
    echo -e "${YELLOW}正在卸载脚本...${NC}"
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
    if [[ -f "$CURRENT_SCRIPT_PATH" ]]; then
        rm -f "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本文件已删除。${NC}"
    else
        echo -e "${YELLOW}脚本文件不存在。${NC}"
    fi
    echo -e "${GREEN}脚本卸载完成。${NC}"
    exit 0
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${GREEN}VPS Manager${NC}"
    echo -e "${BLUE}https://github.com/sillda76/owqq${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${YELLOW}1. 修改DNS${NC}"
    echo -e "${CYAN}2. 系统更新${NC}"
    echo -e "${GREEN}3. 系统清理${NC}"
    echo -e "${BLUE}4. Fail2ban配置${NC}"
    echo -e "${MAGENTA}5. IPv4/IPv6配置${NC}"
    echo -e "${CYAN}6. 添加系统信息${NC}"
    echo -e "${YELLOW}7. SSH命令行美化${NC}"
    echo -e "${GREEN}8. DanmakuRender${NC}"
    echo -e "${BLUE}9. 更新脚本${NC}"
    echo -e "${RED}10.卸载脚本${NC}"
    echo -e "${MAGENTA}0. 退出脚本${NC}"
    echo -e "${MAGENTA}========================================${NC}"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项数字: " choice
    case $choice in
        1) modify_dns ;;
        2) system_update ;;
        3) system_clean ;;
        4) bash <(curl -sL https://raw.githubusercontent.com/sillda76/owqq/refs/heads/main/install_fail2ban.sh) ;;
        5) bash <(curl -sL https://raw.githubusercontent.com/sillda76/owqq/refs/heads/main/IPControlCenter.sh) ;;
        6) bash <(curl -s https://raw.githubusercontent.com/sillda76/owqq/refs/heads/main/system_info.sh) ;;
        7) ssh_beautify ;;
        8) bash <(wget -qO- https://raw.githubusercontent.com/sillda76/DanmakuRender/refs/heads/v5/dmr.sh) ;;
        9) update_script ;;
        10) uninstall_script ;;
        0) echo -e "${MAGENTA}退出脚本。${NC}"; break ;;
        "") echo -e "${RED}错误：未输入选项，请按任意键返回菜单。${NC}"; read -n 1 -s -r -p "" ;;
        *) echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"; read -n 1 -s -r -p "" ;;
    esac
done
