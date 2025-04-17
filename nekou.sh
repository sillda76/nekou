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
CURRENT_SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_URL="https://raw.githubusercontent.com/sillda76/nekou/refs/heads/main/nekou.sh"

# SSH美化内容（萌萌哒提示喵～(ฅ'ω'ฅ)）
BEAUTIFY_CONTENT='
# 命令行美化 - 萌萌哒配置
parse_git_branch() {
    git branch 2> /dev/null | sed -e '\''/^[^*]/d'\'' -e '\''s/* \(.*\)/ (\1)/'\''
}
PS1='\''\[\033[01;38;5;117m\]\u\[\033[01;33m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[01;35m\]$(parse_git_branch)\[\033[00m\] \[\033[01;36m\][\D{%H:%M:%S}]\[\033[00m\]\n\[\033[01;37m\]\$ \[\033[00m\]'\''
# 命令行美化结束 - 快来体验可爱风格吧～(=^･ω･^=)
'

###########################################
# 设置 Q/q 快捷指令（通过符号链接）
###########################################
setup_q_command() {
    # 检查是否已设置
    if [ ! -L "/usr/local/bin/q" ] || [ ! -L "/usr/local/bin/Q" ]; then
        # 创建符号链接
        sudo ln -sf "$CURRENT_SCRIPT_PATH" /usr/local/bin/q
        sudo ln -sf "$CURRENT_SCRIPT_PATH" /usr/local/bin/Q
    fi
}

# 首次运行时设置快捷指令
setup_q_command

###########################################
# 检测网络栈类型（检测网络，喵～(ฅ^•ﻌ•^ฅ)）
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
    echo -e "${CYAN}当前DNS配置如下喵～(＾◡＾)：${NC}"
    cat /etc/resolv.conf
    echo -e "${CYAN}----------------------------------------${NC}"
    
    # 检测当前网络栈
    local network_stack=$(detect_network_stack)
    case $network_stack in
        "dual") echo -e "${GREEN}检测到双栈网络 (IPv4+IPv6) 喵～(ฅ'ω'ฅ)${NC}" ;;
        "ipv4") echo -e "${GREEN}检测到IPv4单栈网络 喵～(ฅ'ω'ฅ)${NC}" ;;
        "ipv6") echo -e "${GREEN}检测到IPv6单栈网络 喵～(ฅ'ω'ฅ)${NC}" ;;
        *) echo -e "${RED}未检测到有效网络连接喵～(╥﹏╥)${NC}" 
           read -n 1 -s -r -p "按任意键返回菜单喵～" 
           return 1 ;;
    esac

    echo -e "${YELLOW}[DNS配置] 请选择 DNS 优化方案喵～(≧◡≦)${NC}"
    echo -e "${YELLOW}1. 国外DNS优化: v4: 1.1.1.1 8.8.8.8, v6: 2606:4700:4700::1111 2001:4860:4860::8888${NC}"
    echo -e "${YELLOW}2. 国内DNS优化: v4: 223.5.5.5 183.60.83.19, v6: 2400:3200::1 2400:da00::6666${NC}"
    echo -e "${YELLOW}3. 手动编辑DNS配置${NC}"
    echo -e "${YELLOW}4. 保持默认${NC}"
    read -p "请输入选项数字喵～: " dns_choice

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
            echo -e "${YELLOW}正在解锁 /etc/resolv.conf 文件喵～(｡•́︿•̀｡)${NC}"
            sudo chattr -i /etc/resolv.conf 2>/dev/null
            echo -e "${YELLOW}正在禁用 systemd-resolved 喵～(｡•́︿•̀｡)${NC}"
            sudo systemctl disable --now systemd-resolved 2>/dev/null
            echo -e "${YELLOW}请使用 nano 编辑 /etc/resolv.conf，修改DNS配置后保存退出喵～(＾◡＾)${NC}"
            sudo nano /etc/resolv.conf
            sudo chattr +i /etc/resolv.conf 2>/dev/null
            echo -e "${GREEN}DNS配置已更新并锁定喵～(=^･ω･^=)${NC}"
            echo -e "${CYAN}新的DNS配置如下喵～(＾◡＾)${NC}"
            cat /etc/resolv.conf
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            return
            ;;
        4) # 保持默认
            echo -e "${GREEN}保持默认DNS配置，未做任何修改喵～(=^･ω･^=)${NC}"
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            return
            ;;
        *)
            echo -e "${RED}错误：无效选项喵～(╥﹏╥)${NC}"
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            return
            ;;
    esac

    # 应用DNS配置
    echo -e "${YELLOW}正在解锁 /etc/resolv.conf 文件喵～(｡•́︿•̀｡)${NC}"
    sudo chattr -i /etc/resolv.conf 2>/dev/null
    echo -e "${YELLOW}正在禁用 systemd-resolved 喵～(｡•́︿•̀｡)${NC}"
    sudo systemctl disable --now systemd-resolved 2>/dev/null
    echo -e "${YELLOW}写入DNS配置喵～(｡•̀ᴗ-)✧${NC}"
    
    # 备份原有配置
    sudo cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    
    # 写入新配置
    echo -e "$dns_config" | sudo tee /etc/resolv.conf >/dev/null
    sudo chattr +i /etc/resolv.conf 2>/dev/null
    
    echo -e "${GREEN}DNS优化已完成～新的DNS配置如下喵～(=^･ω･^=)${NC}"
    cat /etc/resolv.conf
    read -n 1 -s -r -p "按任意键返回菜单喵～"
}

# SSH命令行美化
ssh_beautify() {
    clear
    echo -e "${YELLOW}SSH命令行美化选项喵～(≧◡≦)${NC}"
    echo -e "1. 安装命令行美化 (｡♥‿♥｡)"
    echo -e "2. 卸载命令行美化 (╥﹏╥)"
    echo -e "3. 返回主菜单喵～(ฅ'ω'ฅ)"
    read -p "请输入选项 (1/2/3)喵～: " choice

    case $choice in
        1)
            # 检查是否已存在美化内容
            if grep -q "# 命令行美化" ~/.bashrc; then
                echo -e "${YELLOW}命令行美化已经安装过喵～(｡•́︿•̀｡)${NC}"
            else
                echo "$BEAUTIFY_CONTENT" >> ~/.bashrc
                source ~/.bashrc
                echo -e "${GREEN}命令行美化已安装并立即生效喵～(=^･ω･^=)${NC}"
            fi
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            ;;
        2)
            # 删除美化内容
            if grep -q "# 命令行美化" ~/.bashrc; then
                # 使用sed删除从"# 命令行美化"到"# 命令行美化结束"之间的内容
                sed -i '/# 命令行美化/,/# 命令行美化结束/d' ~/.bashrc
                source ~/.bashrc
                echo -e "${GREEN}命令行美化已卸载并立即生效喵～(｡•́︿•̀｡)${NC}"
            else
                echo -e "${YELLOW}没有找到已安装的命令行美化内容喵～(๑•̀ㅂ•́)و✧${NC}"
            fi
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}无效的选项喵～(╥﹏╥)${NC}"
            read -n 1 -s -r -p "按任意键返回菜单喵～"
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
        echo -e "${RED}未知的包管理器，无法安装 ${package} 喵～(╥﹏╥)${NC}"
        return 1
    fi
}

# 系统更新
system_update() {
    echo -e "${YELLOW}正在系统更新喵～(๑>◡<๑)${NC}"
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
        echo -e "${RED}未知的包管理器，无法执行系统更新喵～(╥﹏╥)${NC}"
    fi
    echo -e "${GREEN}系统更新完成喵～(=^･ω･^=)${NC}"
    read -n 1 -s -r -p "按任意键返回菜单喵～"
}

# 系统清理
system_clean() {
    echo -e "${YELLOW}正在系统清理喵～(｡•̀ᴗ-)✧${NC}"
    steps=(
        "清理包管理器缓存喵～"
        "删除系统日志喵～"
        "删除临时文件喵～"
        "清理 APK 缓存喵～"
        "清理 YUM/DNF 缓存喵～"
        "清理 APT 缓存喵～"
        "清理 Pacman 缓存喵～"
        "清理 Zypper 缓存喵～"
        "清理 Opkg 缓存喵～"
    )
    total_steps=${#steps[@]}
    echo -e "${YELLOW}本次清理将执行以下操作喵～(≧◡≦)${NC}"
    for step in "${steps[@]}"; do
        echo -e "  - ${step}"
    done
    echo -e "${YELLOW}开始清理喵～(๑•̀ㅂ•́)و✧${NC}"
    for ((i = 0; i < total_steps; i++)); do
        echo -e "${YELLOW}${steps[$i]}${NC}"
        case ${steps[$i]} in
            "清理包管理器缓存喵～")
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
            "删除系统日志喵～")
                journalctl --rotate
                journalctl --vacuum-time=1s
                journalctl --vacuum-size=500M
                ;;
            "删除临时文件喵～")
                rm -rf /tmp/*
                rm -rf /var/tmp/*
                ;;
            "清理 APK 缓存喵～")
                [ -x "$(command -v apk)" ] && apk cache clean
                ;;
            "清理 YUM/DNF 缓存喵～")
                if command -v dnf &>/dev/null; then
                    dnf clean all
                elif command -v yum &>/dev/null; then
                    yum clean all
                fi
                ;;
            "清理 APT 缓存喵～")
                [ -x "$(command -v apt)" ] && { apt clean; apt autoclean; }
                ;;
            "清理 Pacman 缓存喵～")
                [ -x "$(command -v pacman)" ] && pacman -Scc --noconfirm
                ;;
            "清理 Zypper 缓存喵～")
                [ -x "$(command -v zypper)" ] && zypper clean --all
                ;;
            "清理 Opkg 缓存喵～")
                [ -x "$(command -v opkg)" ] && opkg clean
                ;;
        esac
    done
    echo -e "\n${GREEN}系统清理完成喵～(=^･ω･^=)${NC}"
    read -n 1 -s -r -p "按任意键返回菜单喵～"
}

# 更新脚本
update_script() {
    echo -e "${YELLOW}正在更新脚本喵～(｡•̀ᴗ-)✧${NC}"
    if curl -s "$SCRIPT_URL" -o "$CURRENT_SCRIPT_PATH"; then
        chmod +x "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本更新成功喵～(=^･ω･^=) 按任意键返回菜单喵～${NC}"
        read -n 1 -s -r -p ""
        exec "$CURRENT_SCRIPT_PATH"
    else
        echo -e "${RED}脚本更新失败，请检查网络连接或 URL 是否正确喵～(╥﹏╥)${NC}"
        read -n 1 -s -r -p "按任意键返回菜单喵～"
    fi
}

# 卸载脚本
uninstall_script() {
    echo -e "${YELLOW}正在卸载脚本喵～(｡•́︿•̀｡)${NC}"
    
    # 删除符号链接
    if [ -L "/usr/local/bin/q" ]; then
        sudo rm -f /usr/local/bin/q
    fi
    
    if [ -L "/usr/local/bin/Q" ]; then
        sudo rm -f /usr/local/bin/Q
    fi
    
    # 删除脚本文件
    if [[ -f "$CURRENT_SCRIPT_PATH" ]]; then
        rm -f "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本文件已删除喵～(=^･ω･^=)${NC}"
    else
        echo -e "${YELLOW}脚本文件不存在喵～(๑•̀ㅂ•́)و✧${NC}"
    fi
    
    echo -e "${GREEN}脚本卸载完成喵～(=^･ω･^=)${NC}"
    exit 0
}

# 显示主菜单（超级可爱菜单喵～(ฅ'ω'ฅ)）
show_menu() {
    clear
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${GREEN}萌萌VPS 管理器喵～(=^･ω･^=)${NC}"
    echo -e "${BLUE}https://github.com/sillda76/nekou${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${YELLOW}1. 修改DNS喵～(≧◡≦)${NC}"
    echo -e "${CYAN}2. 系统更新喵～(๑>◡<๑)${NC}"
    echo -e "${GREEN}3. 系统清理喵～(=^･ω･^=)${NC}"
    echo -e "${BLUE}4. Fail2ban配置喵～(=^･ω･^=)${NC}"
    echo -e "${MAGENTA}5. IPv4/IPv6配置喵～(=^･ω･^=)${NC}"
    echo -e "${CYAN}6. 添加系统信息喵～(=^･ω･^=)${NC}"
    echo -e "${YELLOW}7. SSH命令行美化喵～(ฅ'ω'ฅ)${NC}"
    echo -e "${GREEN}8. 超萌BBR管理脚本喵～(ฅ'ω'ฅ)${NC}"
    echo -e "${BLUE}9. DanmakuRender喵～(ฅ'ω'ฅ)${NC}"
    echo -e "${MAGENTA}10.更新脚本喵～(ฅ'ω'ฅ)${NC}"
    echo -e "${CYAN}11.卸载脚本喵～(ฅ'ω'ฅ)${NC}"
    echo -e "${RED}0. 退出脚本喵～(╥﹏╥)${NC}"
    echo -e "${MAGENTA}========================================${NC}"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项数字喵～: " choice
    case $choice in
        1) modify_dns ;;
        2) system_update ;;
        3) system_clean ;;
        4) bash <(curl -sL https://raw.githubusercontent.com/sillda76/nekou/refs/heads/main/install_fail2ban.sh) ;;
        5) bash <(curl -sL https://raw.githubusercontent.com/sillda76/nekou/refs/heads/main/IPControlCenter.sh) ;;
        6) bash <(curl -s https://raw.githubusercontent.com/sillda76/nekou/refs/heads/main/system_info.sh) ;;
        7) ssh_beautify ;;
        8) 
            echo -e "${GREEN}正在执行超萌BBR管理脚本喵～(=^･ω･^=)${NC}"
            sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/byJoey/Actions-bbr-v3/refs/heads/main/install.sh)"
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            ;;
        9) bash <(wget -qO- https://raw.githubusercontent.com/sillda76/DanmakuRender/refs/heads/v5/dmr.sh) ;;
        10) update_script ;;
        11) uninstall_script ;;
        0) echo -e "${MAGENTA}退出脚本喵～(╥﹏╥)${NC}"; break ;;
        "") echo -e "${RED}错误：未输入选项喵～(╥﹏╥)${NC}"; read -n 1 -s -r -p "" ;;
        *) echo -e "${RED}错误：无效选项喵～(╥﹏╥)${NC}"; read -n 1 -s -r -p "" ;;
    esac
done
