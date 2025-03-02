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

# 进度条函数
progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=$((progress * bar_width / total))
    local empty=$((bar_width - filled))

    printf "["
    for ((i=0; i<filled; i++)); do
        if ((i < filled / 3)); then
            printf "${GREEN}=${NC}"
        elif ((i < 2 * filled / 3)); then
            printf "${YELLOW}=${NC}"
        else
            printf "${RED}=${NC}"
        fi
    done
    for ((i=0; i<empty; i++)); do
        printf "${BLACK}=${NC}"
    done
    printf "]"
}

# 安装依赖工具
install_dependencies() {
    echo -e "${YELLOW}正在安装依赖工具...${NC}"
    if ! command -v bc &> /dev/null; then
        sudo apt install bc -y || { echo -e "${RED}安装 bc 失败！${NC}"; exit 1; }
    fi
    if ! command -v jq &> /dev/null; then
        sudo apt install jq -y || { echo -e "${RED}安装 jq 失败！${NC}"; exit 1; }
    fi
    sudo apt install net-tools curl -y || { echo -e "${RED}安装依赖失败！${NC}"; exit 1; }
}

# 卸载函数
uninstall() {
    echo -e "${YELLOW}正在卸载系统信息工具...${NC}"

    # 删除系统信息脚本
    if [[ -f ~/.local/sysinfo.sh ]]; then
        rm -f ~/.local/sysinfo.sh
    fi

    # 清理 bashrc 配置
    sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc
    sed -i '/# PS1 CUSTOM CONFIG START/,/# PS1 CUSTOM CONFIG END/d' ~/.bashrc

    # 恢复 motd 文件
    if [[ -f /etc/motd.bak ]]; then
        sudo mv /etc/motd.bak /etc/motd
    elif [[ -f /etc/motd ]]; then
        sudo truncate -s 0 /etc/motd
    fi

    # 删除配置文件
    rm -f ~/.local/sysinfo_asn_display

    echo -e "${GREEN}系统信息工具已卸载！${NC}"
}

# 切换 ASN 显示模式
switch_asn_display() {
    current_mode=$(cat ~/.local/sysinfo_asn_display 2>/dev/null || echo "ipv4")
    new_mode="ipv6"
    if [[ "$current_mode" == "ipv6" ]]; then
        new_mode="ipv4"
    fi
    echo "$new_mode" > ~/.local/sysinfo_asn_display
    echo -e "${GREEN}已切换显示模式：${new_mode} ASN/ISP 信息${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 安装函数
install() {
    # 检查现有安装
    if check_installed; then
        read -p "系统信息工具已安装，继续安装将重新配置，是否继续？[y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${YELLOW}已取消安装${NC}"
            return
        else
            uninstall
        fi
    fi

    # 创建本地目录
    mkdir -p ~/.local

    # 安装依赖
    install_dependencies

    # 备份 motd 文件
    if [[ -f /etc/motd ]]; then
        sudo cp /etc/motd /etc/motd.bak
        sudo truncate -s 0 /etc/motd
    fi

    # 生成系统信息脚本
    cat << 'EOF' > ~/.local/sysinfo.sh
#!/bin/bash

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
NC='\033[0m'

# 进度条显示
progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=$((progress * bar_width / total))
    local empty=$((bar_width - filled))

    printf "["
    for ((i=0; i<filled; i++)); do
        if ((i < filled/3)); then printf "\${GREEN}=\${NC}";
        elif ((i < 2*filled/3)); then printf "\${YELLOW}=\${NC}";
        else printf "\${RED}=\${NC}"; fi
    done
    for ((i=0; i<empty; i++)); do printf "\${BLACK}=\${NC}"; done
    printf "]"
}

# 获取 ASN/ISP 信息
get_asn_info() {
    local ip=$1
    local response=$(curl -s --max-time 3 "https://ipinfo.io/$ip?token=3b01046f048430")
    local asn=$(echo "$response" | jq -r '.org' | awk '{print $1}')
    local isp=$(echo "$response" | jq -r '.org' | awk '{$1=""; print $0}' | sed 's/^ //')
    
    if [[ "$asn" != "null" && -n "$asn" ]]; then
        echo -e "\${BLUE}ASN:\${NC} $asn  \${BLUE}ISP:\${NC} $isp"
    else
        echo -e "\${RED}ASN/ISP: 未找到信息\${NC}"
    fi
}

# 主显示逻辑
main_display() {
    # 系统基础信息
    os_info=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    uptime_sec=$(awk '{print $1}' /proc/uptime)
    uptime_days=$(bc <<< "scale=0; $uptime_sec/86400")
    uptime_hrs=$(bc <<< "scale=0; ($uptime_sec%86400)/3600")
    uptime_min=$(bc <<< "scale=0; ($uptime_sec%3600)/60")
    
    # CPU 信息
    cpu_info=$(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//')
    cpu_cores=$(nproc)
    load_avg=$(awk '{print $1", "$2", "$3}' /proc/loadavg)

    # 内存信息
    mem_total=$(free -m | awk '/Mem:/{print $2}')
    mem_used=$(free -m | awk '/Mem:/{print $3}')
    swap_total=$(free -m | awk '/Swap:/{print $2}')
    swap_used=$(free -m | awk '/Swap:/{print $3}')

    # 磁盘信息
    disk_total=$(df -k / | awk 'NR==2{print $2}')
    disk_used=$(df -k / | awk 'NR==2{print $3}')

    # 网络流量
    interface=$(ip route | awk '/default/{print $5; exit}')
    rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    format_bytes() {
        bytes=$1
        if (( bytes >= 1099511627776 )); then
            echo "$(bc <<< "scale=2; $bytes/1099511627776") TB"
        elif (( bytes >= 1073741824 )); then
            echo "$(bc <<< "scale=2; $bytes/1073741824") GB"
        else
            echo "$(bc <<< "scale=2; $bytes/1048576") MB"
        fi
    }

    # 公网 IP 信息
    ipv4=$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
    ipv6=$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)
    display_mode=$(cat ~/.local/sysinfo_asn_display 2>/dev/null || echo "ipv4")

    # 信息输出
    echo -e "\n${ORANGE}系统信息：${NC}"
    echo -e "${ORANGE}OS:\${NC}        $os_info"
    echo -e "${ORANGE}运行时间:\${NC}  ${uptime_days}天 ${uptime_hrs}小时 ${uptime_min}分钟"
    echo -e "${ORANGE}CPU:\${NC}       ${cpu_info} (${cpu_cores} 核心)"
    echo -e "${ORANGE}负载:\${NC}      ${load_avg}"

    # 内存显示
    echo -ne "${ORANGE}内存使用:\${NC}  "
    progress_bar $mem_used $mem_total
    echo " $mem_used MB / $mem_total MB ($(bc <<< "scale=0; 100*$mem_used/$mem_total")%)"

    # 交换分区显示
    if (( swap_total > 0 )); then
        echo -ne "${ORANGE}交换分区:\${NC}  "
        progress_bar $swap_used $swap_total
        echo " $swap_used MB / $swap_total MB ($(bc <<< "scale=0; 100*$swap_used/$swap_total")%)"
    fi

    # 磁盘显示
    echo -ne "${ORANGE}磁盘使用:\${NC}  "
    progress_bar $disk_used $disk_total
    echo " $(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"})"

    # 网络流量
    echo -e "${ORANGE}网络流量:\${NC}  TX: $(format_bytes $tx_bytes)  RX: $(format_bytes $rx_bytes)"

    # IP 和 ASN 显示
    echo -e "\n${ORANGE}网络信息：${NC}"
    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:\${NC} $ipv4"
        if [[ "$display_mode" == "ipv4" ]]; then
            get_asn_info "$ipv4"
        fi
    fi
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* ]]; then
        echo -e "${GREEN}IPv6:\${NC} $ipv6"
        if [[ "$display_mode" == "ipv6" ]]; then
            get_asn_info "$ipv6"
        fi
    fi
    [[ -z "$ipv4" && -z "$ipv6" ]] && echo -e "${RED}未检测到公网IP${NC}"
}

main_display
EOF

    # 设置执行权限
    chmod +x ~/.local/sysinfo.sh

    # 配置 SSH 登录显示
    if ! grep -q '# SYSINFO SSH LOGIC START' ~/.bashrc; then
        echo -e "\n# SYSINFO SSH LOGIC START" >> ~/.bashrc
        echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    # 添加 PS1 配置
    if ! grep -q '# PS1 CUSTOM CONFIG START' ~/.bashrc; then
        echo -e "\n# PS1 CUSTOM CONFIG START" >> ~/.bashrc
        echo 'parse_git_branch() {' >> ~/.bashrc
        echo '    git branch 2> /dev/null | sed -e '\''/^[^*]/d'\'' -e '\''s/* \(.*\)/ (\1)/'\''' >> ~/.bashrc
        echo '}' >> ~/.bashrc
        echo 'PS1='\''\[\033[01;38;5;117m\]\u\[\033[01;33m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[01;35m\]$(parse_git_branch)\[\033[00m\] \[\033[01;36m\][\D{%H:%M:%S}]\[\033[00m\]\n\[\033[01;37m\]\$ \[\033[00m\]'\''' >> ~/.bashrc
        echo '# PS1 CUSTOM CONFIG END' >> ~/.bashrc
    fi

    # 初始化 ASN 显示模式
    echo "ipv4" > ~/.local/sysinfo_asn_display

    echo -e "\n${GREEN}安装完成！${NC}"
    echo -e "默认显示 IPv4 的 ASN/ISP 信息，可通过菜单选项切换显示模式"
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 主菜单
show_menu() {
    while true; do
        clear
        echo -e "${CYAN}==================================="
        echo " SSH 系统信息管理工具"
        echo -e "===================================${NC}"
        echo -e "1. 安装/重新安装系统信息工具"
        echo -e "2. 完全卸载系统信息工具"
        echo -e "3. 切换 ASN/ISP 显示模式"
        echo -e "0. 退出程序"
        echo -e "${CYAN}===================================${NC}"
        echo -e "当前状态：$(check_installed)"
        echo -e "ASN显示模式：$(cat ~/.local/sysinfo_asn_display 2>/dev/null || echo ipv4)"
        echo -e "${CYAN}===================================${NC}"
        read -p "请输入选项 (0-3): " choice

        case $choice in
            1) install ;;
            2) uninstall
               read -n 1 -s -r -p "按任意键继续..." ;;
            3) switch_asn_display ;;
            0) echo -e "${GREEN}退出程序${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 启动主菜单
show_menu
