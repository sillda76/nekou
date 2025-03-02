#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
NC='\033[0m'

# 检查是否已安装
check_installed() {
    if [[ -f ~/.local/sysinfo.sh ]] && grep -q '# SYSINFO SSH LOGIC START' ~/.bashrc; then
        echo -e "${GREEN}已安装${NC}"
        return 0
    else
        echo -e "${RED}未安装${NC}"
        return 1
    fi
}

# 进度条函数（优化版）
progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=$((progress * bar_width / total))
    local filled_percent=$((progress * 100 / total))

    printf "["
    for ((i=0; i<bar_width; i++)); do
        if ((i < filled)); then
            if ((filled_percent < 33)); then
                printf "${GREEN}=${NC}"
            elif ((filled_percent < 66)); then
                printf "${YELLOW}=${NC}"
            else
                printf "${RED}=${NC}"
            fi
        else
            printf "${BLACK}=${NC}"
        fi
    done
    printf "]"
}

# 获取IP运营商信息
get_ip_isp() {
    local ip=$1
    [[ -z "$ip" ]] && return

    local isp=$(curl -s --max-time 2 "https://ipinfo.io/$ip/org?token=YOUR_API_TOKEN" | sed 's/.*"\(.*\)"/\1/')
    [[ -n "$isp" ]] && echo -e "${BLUE}ISP:${NC} ${isp%% *}" || return
}

# 安装依赖工具
install_dependencies() {
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}未找到 bc 工具，正在安装...${NC}"
        sudo apt install bc -y || { echo -e "${RED}安装 bc 失败！${NC}"; exit 1; }
    fi
    sudo apt install net-tools curl -y || { echo -e "${RED}安装依赖失败！${NC}"; exit 1; }
}

# 卸载函数
uninstall() {
    echo -e "${YELLOW}正在卸载系统信息工具...${NC}"

    # 删除系统信息脚本
    [[ -f ~/.local/sysinfo.sh ]] && rm -f ~/.local/sysinfo.sh

    # 清理bashrc配置
    sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc
    sed -i '/# CUSTOM PROMPT START/,/# CUSTOM PROMPT END/d' ~/.bashrc

    # 恢复motd文件
    [[ -f /etc/motd.bak ]] && sudo mv /etc/motd.bak /etc/motd

    echo -e "${GREEN}系统信息工具已卸载！${NC}"
}

# 安装函数
install() {
    if check_installed; then
        read -p "系统信息工具已安装，是否重新安装？[y/N]: " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return
        uninstall
    fi

    mkdir -p ~/.local
    install_dependencies

    # 备份motd文件
    [[ -f /etc/motd ]] && sudo cp /etc/motd /etc/motd.bak && sudo truncate -s 0 /etc/motd

    # 创建系统信息脚本
    cat << 'EOF' > ~/.local/sysinfo.sh
#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
NC='\033[0m'

progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=$((progress * bar_width / total))
    local filled_percent=$((progress * 100 / total))

    printf "["
    for ((i=0; i<bar_width; i++)); do
        if ((i < filled)); then
            if ((filled_percent < 33)); then
                printf "${GREEN}=${NC}"
            elif ((filled_percent < 66)); then
                printf "${YELLOW}=${NC}"
            else
                printf "${RED}=${NC}"
            fi
        else
            printf "${BLACK}=${NC}"
        fi
    done
    printf "]"
}

get_public_ip() {
    declare -A ips
    ips[ipv4]=$(curl -s --max-time 2 ipv4.icanhazip.com || curl -s --max-time 2 ifconfig.me)
    ips[ipv6]=$(curl -s --max-time 2 ipv6.icanhazip.com | grep -v 'DOCTYPE' | grep -v '^$')
    
    # 优先显示IPv4
    if [[ -n "${ips[ipv4]}" ]]; then
        echo -e "${GREEN}IPv4:${NC} ${ips[ipv4]}"
        isp=$(curl -s --max-time 2 "https://ipinfo.io/${ips[ipv4]}/org?token=3b01046f048430")
        [[ -n "$isp" ]] && echo -e "${BLUE}ISP:${NC} ${isp%% *}"
    elif [[ -n "${ips[ipv6]}" ]]; then
        echo -e "${GREEN}IPv6:${NC} ${ips[ipv6]}"
        isp=$(curl -s --max-time 2 "https://ipinfo.io/${ips[ipv6]}/org?token=3b01046f048430")
        [[ -n "$isp" ]] && echo -e "${BLUE}ISP:${NC} ${isp%% *}"
    fi
}

# 系统信息展示逻辑
get_public_ip
EOF

    chmod +x ~/.local/sysinfo.sh

    # 添加SSH登录显示
    if ! grep -q '# SYSINFO SSH LOGIC START' ~/.bashrc; then
        cat << 'EOF' >> ~/.bashrc
# SYSINFO SSH LOGIC START
if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then
    bash ~/.local/sysinfo.sh
fi
# SYSINFO SSH LOGIC END
EOF
    fi

    # 添加PS1配置
    if ! grep -q '# CUSTOM PROMPT START' ~/.bashrc; then
        cat << 'EOF' >> ~/.bashrc
# CUSTOM PROMPT START
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[01;38;5;117m\]\u\[\033[01;33m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[01;35m\]$(parse_git_branch)\[\033[00m\] \[\033[01;36m\][\D{%H:%M:%S}]\[\033[00m\]\n\[\033[01;37m\]\$ \[\033[00m\]'
# CUSTOM PROMPT END
EOF
        echo -e "${GREEN}PS1提示符配置完成！${NC}"
    fi

    echo -e "${GREEN}系统信息工具安装完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 主菜单
show_menu() {
    while true; do
        clear
        echo -e "${ORANGE}=========================${NC}"
        echo -e "${ORANGE}      系统信息管理      ${NC}"
        echo -e "${ORANGE}1. 安装/重新安装${NC}"
        echo -e "${ORANGE}2. 卸载${NC}"
        echo -e "${ORANGE}0. 退出${NC}"
        echo -e "${ORANGE}当前状态：$(check_installed)${NC}"
        echo -e "${ORANGE}=========================${NC}"
        read -p "请输入选项: " choice

        case $choice in
            1) install ;;
            2) uninstall ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

show_menu
