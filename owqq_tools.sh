#!/bin/bash
# 定义超可爱颜色变量 (ღ˘⌣˘ღ)
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# 当前脚本路径及远程脚本 URL（用于更新）(✿◠‿◠)
CURRENT_SCRIPT_PATH="$(pwd)/owqq_tools.sh"
SCRIPT_URL="https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/owqq_tools.sh"

# SSH命令行美化内容 (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧
BEAUTIFY_CONTENT='
# 超可爱命令行美化 (⁄ ⁄•⁄ω⁄•⁄ ⁄)
parse_git_branch() {
    git branch 2> /dev/null | sed -e '\''/^[^*]/d'\'' -e '\''s/* \(.*\)/ (\1)/'\''
}
PS1='\''\[\033[01;38;5;117m\]\u\[\033[01;33m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[01;35m\]$(parse_git_branch)\[\033[00m\] \[\033[01;36m\][\D{%H:%M:%S}]\[\033[00m\]\n\[\033[01;37m\]\$ \[\033[00m\]'\''
# 命令行美化完毕，超级萌萌哒喵～ (｡♥‿♥｡)
'

# 设置超级可爱快捷启动命令 alias (づ｡◕‿‿◕｡)づ
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
    echo -e "${CYAN}嘻嘻，快捷命令已经设置好啦～ヾ(≧▽≦*)o${NC}"
}

setup_alias

# 检测网络栈类型 (ﾉ´ヮ)ﾉ*: ･ﾟ
detect_network_stack() {
    local has_ipv4=0
    local has_ipv6=0

    # 检查IPv4 (＾▽＾)
    if ip -4 route get 8.8.8.8 &>/dev/null; then
        has_ipv4=1
    fi

    # 检查IPv6 (☆▽☆)
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

# 修改DNS配置 (´｡• ᵕ •｡`)
modify_dns() {
    clear
    echo -e "${CYAN}当前DNS配置萌萌哒：${NC}"
    cat /etc/resolv.conf
    echo -e "${CYAN}----------------------------------------${NC}"
    
    # 检测网络栈 (♥ω♥*)
    local network_stack=$(detect_network_stack)
    case $network_stack in
        "dual") echo -e "${GREEN}嘻嘻，检测到双栈网络 (IPv4+IPv6)呢～(づ｡◕‿‿◕｡)づ${NC}" ;;
        "ipv4") echo -e "${GREEN}检测到只有IPv4单栈网络哦～(＾▽＾)${NC}" ;;
        "ipv6") echo -e "${GREEN}检测到只有IPv6单栈网络哦～(☆▽☆)${NC}" ;;
        *) echo -e "${RED}哎呀，未检测到网络连接呢 (｡•́︿•̀｡)${NC}" 
           read -n 1 -s -r -p "按任意键返回菜单喵～"
           return 1 ;;
    esac

    echo -e "${YELLOW}[DNS配置] 请选择萌萌哒的DNS优化方案：${NC}"
    echo -e "${YELLOW}1. 国外DNS优化: v4: 1.1.1.1 8.8.8.8, v6: 2606:4700:4700::1111 2001:4860:4860::8888${NC}"
    echo -e "${YELLOW}2. 国内DNS优化: v4: 223.5.5.5 183.60.83.19, v6: 2400:3200::1 2400:da00::6666${NC}"
    echo -e "${YELLOW}3. 手动编辑DNS配置 (o´ω`o)"
    echo -e "${YELLOW}4. 保持默认 (｡•́︿•̀｡)"
    read -p "请输入选项数字: " dns_choice

    # 准备DNS配置 (≧◡≦)
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
            echo -e "${YELLOW}正在解锁 /etc/resolv.conf 文件呢... (ฅ'ω'ฅ)${NC}"
            sudo chattr -i /etc/resolv.conf 2>/dev/null
            echo -e "${YELLOW}正在禁用 systemd-resolved喵... (๑•̀ㅂ•́)و✧${NC}"
            sudo systemctl disable --now systemd-resolved 2>/dev/null
            echo -e "${YELLOW}请用 nano 编辑 /etc/resolv.conf，修改完记得保存哦～ (´｡• ᵕ •｡`)${NC}"
            sudo nano /etc/resolv.conf
            sudo chattr +i /etc/resolv.conf 2>/dev/null
            echo -e "${GREEN}DNS配置更新成功，锁定完毕啦！(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧${NC}"
            echo -e "${CYAN}新的DNS配置如下：${NC}"
            cat /etc/resolv.conf
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            return
            ;;
        4) # 保持默认
            echo -e "${GREEN}好的，保持默认DNS配置咯～ (｡◕‿◕｡)"
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            return
            ;;
        *)
            echo -e "${RED}哎呀，选项不对呢 (｡•́︿•̀｡)${NC}"
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            return
            ;;
    esac

    # 应用DNS配置
    echo -e "${YELLOW}正在解锁 /etc/resolv.conf 文件呢... (ฅ'ω'ฅ)${NC}"
    sudo chattr -i /etc/resolv.conf 2>/dev/null
    echo -e "${YELLOW}正在禁用 systemd-resolved喵... (๑•̀ㅂ•́)و✧${NC}"
    sudo systemctl disable --now systemd-resolved 2>/dev/null
    echo -e "${YELLOW}写入DNS配置中，嘻嘻～ (≧◡≦)${NC}"
    
    # 备份原有配置
    sudo cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    
    # 写入新配置
    echo -e "$dns_config" | sudo tee /etc/resolv.conf >/dev/null
    sudo chattr +i /etc/resolv.conf 2>/dev/null
    
    echo -e "${GREEN}DNS优化搞定啦～ (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ 新的DNS配置如下：${NC}"
    cat /etc/resolv.conf
    read -n 1 -s -r -p "按任意键返回菜单喵～"
}

# SSH命令行美化 (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧
ssh_beautify() {
    clear
    echo -e "${YELLOW}SSH命令行美化选项呦：${NC}"
    echo -e "1. 安装命令行美化 (≧◡≦)  ~"
    echo -e "2. 卸载命令行美化 (；⌣̀_⌣́)～"
    echo -e "3. 返回主菜单 (＾▽＾)♪"
    read -p "请输入选项 (1/2/3): " choice

    case $choice in
        1)
            if grep -q "# 命令行美化" ~/.bashrc; then
                echo -e "${YELLOW}命令行美化已经装过啦～ (〃ﾟ3ﾟ〃)"
            else
                echo "$BEAUTIFY_CONTENT" >> ~/.bashrc
                echo -e "${GREEN}命令行美化安装成功喵～请重启终端或执行 'source ~/.bashrc' 哦！(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"
            fi
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            ;;
        2)
            if grep -q "# 命令行美化" ~/.bashrc; then
                sed -i '/# 命令行美化/,/# 命令行美化结束/d' ~/.bashrc
                echo -e "${GREEN}命令行美化卸载成功啦～ (｡•́︿•̀｡)"
            else
                echo -e "${YELLOW}没有找到命令行美化设置呢～ (•̀ᴗ•́)و ̑̑"
            fi
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}哎呀，选项不对呢 (｡•́︿•̀｡)"
            read -n 1 -s -r -p "按任意键返回菜单喵～"
            ;;
    esac
}

# 通用安装包管理器函数 (´∀｀)♡
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
        echo -e "${RED}哎呀，未知的包管理器，无法安装 ${package}呢 (｡•́︿•̀｡)${NC}"
        return 1
    fi
}

# 系统更新 (✿◠‿◠)
system_update() {
    echo -e "${YELLOW}正在努力更新系统中，请稍候喵～ (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧${NC}"
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
        echo -e "${RED}哎呀，未知的包管理器，无法更新系统呢 (｡•́︿•̀｡)${NC}"
    fi
    echo -e "${GREEN}系统更新完成啦～ (*≧ω≦) 喵~${NC}"
    read -n 1 -s -r -p "按任意键返回菜单喵～"
}

# 系统清理 (ﾉ´ヮ)ﾉ*: ･ﾟ
system_clean() {
    echo -e "${YELLOW}正在萌萌哒地清理系统中～(｡♥‿♥｡)${NC}"
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
    echo -e "${YELLOW}本次清理将执行以下超可爱操作：${NC}"
    for step in "${steps[@]}"; do
        echo -e "  - ${step}"
    done
    echo -e "${YELLOW}开始清理啦～ (≧◡≦) ♡${NC}"
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
    echo -e "\n${GREEN}系统清理完成啦～ ٩(๑❛ᴗ❛๑)۶ 喵~${NC}"
    read -n 1 -s -r -p "按任意键返回菜单喵～"
}

# 更新脚本 (✿◠‿◠)
update_script() {
    echo -e "${YELLOW}正在更新脚本，请稍候呦～ (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧${NC}"
    if curl -s "$SCRIPT_URL" -o "$CURRENT_SCRIPT_PATH"; then
        chmod +x "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本更新成功啦～ (*≧ω≦) 喵~ 按任意键返回菜单。${NC}"
        read -n 1 -s -r -p ""
        exec "$CURRENT_SCRIPT_PATH"
    else
        echo -e "${RED}脚本更新失败啦，请检查网络或URL哦 (｡•́︿•̀｡)${NC}"
        read -n 1 -s -r -p "按任意键返回菜单喵～"
    fi
}

# 卸载脚本 (｡•́︿•̀｡)
uninstall_script() {
    echo -e "${YELLOW}正在卸载脚本呦～ (ฅ'ω'ฅ)${NC}"
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
        echo -e "${RED}哎呀，找不到Shell配置文件，无法删除快捷命令呢 (｡•́︿•̀｡)${NC}"
        return
    fi
    if grep -q "alias q=" "$shell_rc"; then
        sed -i '/alias q=/d' "$shell_rc"
        echo -e "${GREEN}快捷启动命令 'q' 已经删除咯～ (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧${NC}"
    else
        echo -e "${YELLOW}快捷启动命令 'q' 不存在哦～ (｡•́︿•̀｡)${NC}"
    fi
    if [[ -f "$CURRENT_SCRIPT_PATH" ]]; then
        rm -f "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本文件删除成功啦～ (✿◠‿◠)${NC}"
    else
        echo -e "${YELLOW}脚本文件已经不在啦～ (｡•́︿•̀｡)${NC}"
    fi
    echo -e "${GREEN}脚本卸载完成啦～ (づ｡◕‿‿◕｡)づ 喵~${NC}"
    exit 0
}

# 显示主菜单 (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧
show_menu() {
    clear
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${GREEN}超级萌VPS Manager (｡◕‿◕｡) 喵~${NC}"
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
    echo -e "${RED}10. 卸载脚本${NC}"
    echo -e "${MAGENTA}11. 超萌BBR管理脚本${NC}"
    echo -e "${MAGENTA}0. 退出脚本 (｡•́︿•̀｡) 喵~${NC}"
    echo -e "${MAGENTA}========================================${NC}"
}

# 主循环 (づ｡◕‿‿◕｡)づ
while true; do
    show_menu
    read -p "请输入选项数字呦： " choice
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
        11)
            echo -e "${YELLOW}正在安装超萌BBR管理脚本～ヾ(≧▽≦*)o 喵~${NC}"
            wget https://raw.githubusercontent.com/byJoey/Actions-bbr-v3/refs/heads/main/install.sh && chmod +x install.sh && sudo ./install.sh
            read -n 1 -s -r -p "按任意键返回菜单呦～"
            ;;
        0) echo -e "${MAGENTA}退出脚本啦～再见亲亲 (｡•́︿•̀｡) 喵~${NC}"; break ;;
        "") echo -e "${RED}哎呀，没输入选项呢 (｡•́︿•̀｡) 请按任意键返回菜单呦～${NC}"; read -n 1 -s -r -p "" ;;
        *) echo -e "${RED}选项不对哦 (｡•́︿•̀｡) 请按任意键返回菜单呦～${NC}"; read -n 1 -s -r -p "" ;;
    esac
done
