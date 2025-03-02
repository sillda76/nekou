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

# -------------------------------
# 检查是否已安装系统信息工具
# -------------------------------
check_installed() {
    if [[ -f ~/.local/sysinfo.sh ]] && grep -q '# SYSINFO SSH LOGIC START' ~/.bashrc; then
        echo -e "${GREEN}已安装${NC}"
        return 0
    else
        echo -e "${RED}未安装${NC}"
        return 1
    fi
}

# -------------------------------
# 进度条函数（用于内存和磁盘使用情况显示）
# -------------------------------
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

# -------------------------------
# 安装依赖工具（bc、net-tools、curl）
# -------------------------------
install_dependencies() {
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}未找到 bc 工具，正在安装...${NC}"
        sudo apt install bc -y || { echo -e "${RED}安装 bc 失败！${NC}"; exit 1; }
    fi
    sudo apt install net-tools curl -y || { echo -e "${RED}安装依赖失败！${NC}"; exit 1; }
}

# -------------------------------
# 获取公网 IP（旧方法保留，仅供参考）
# -------------------------------
get_public_ip() {
    ipv4=$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
    ipv6=$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)

    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:${NC} $ipv4"
    fi
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* && "$ipv6" != "$ipv4" ]]; then
        echo -e "${GREEN}IPv6:${NC} $ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi
}

# -------------------------------
# 卸载函数，删除系统信息脚本以及 ~/.bashrc 中添加的内容
# -------------------------------
uninstall() {
    echo -e "${YELLOW}正在卸载系统信息工具...${NC}"

    if [[ -f ~/.local/sysinfo.sh ]]; then
        echo -e "${YELLOW}删除系统信息脚本...${NC}"
        rm -f ~/.local/sysinfo.sh
    fi

    if grep -q '# SYSINFO SSH LOGIC START' ~/.bashrc; then
        echo -e "${YELLOW}清理 ~/.bashrc 配置...${NC}"
        sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc
    fi

    # 清除 Git 分支解析与 PS1 定制部分
    if grep -q '# GIT BRANCH AND PS1 CUSTOMIZATION START' ~/.bashrc; then
        echo -e "${YELLOW}清理 ~/.bashrc 的 Git PS1 定制内容...${NC}"
        sed -i '/# GIT BRANCH AND PS1 CUSTOMIZATION START/,/# GIT BRANCH AND PS1 CUSTOMIZATION END/d' ~/.bashrc
    fi

    if [[ -f /etc/motd.bak ]]; then
        echo -e "${YELLOW}还原 /etc/motd 文件...${NC}"
        sudo mv /etc/motd.bak /etc/motd
    elif [[ -f /etc/motd ]]; then
        echo -e "${YELLOW}清空 /etc/motd 文件...${NC}"
        sudo truncate -s 0 /etc/motd
    fi

    if [[ -f ~/.local/sysinfo_backup.tar.gz ]]; then
        echo -e "${YELLOW}删除临时备份文件...${NC}"
        rm -f ~/.local/sysinfo_backup.tar.gz
    fi

    echo -e "${GREEN}系统信息工具已卸载！${NC}"
}

# -------------------------------
# 切换 IPv4/IPv6 的 ASN 运营商显示模式（修改配置文件 ~/.local/ipinfo_mode）
# -------------------------------
toggle_ipinfo_mode() {
    config_file=~/.local/ipinfo_mode
    if [[ -f "$config_file" ]]; then
        mode=$(cat "$config_file")
        if [[ "$mode" == "ipv4" ]]; then
            echo "ipv6" > "$config_file"
            echo -e "${GREEN}已切换为 IPv6 的 ASN 运营商显示${NC}"
        else
            echo "ipv4" > "$config_file"
            echo -e "${GREEN}已切换为 IPv4 的 ASN 运营商显示${NC}"
        fi
    else
        echo "ipv4" > "$config_file"
        echo -e "${GREEN}默认设置为 IPv4 的 ASN 运营商显示${NC}"
    fi
}

# -------------------------------
# 安装函数（安装系统信息工具、备份 /etc/motd、写入 ~/.local/sysinfo.sh 以及修改 ~/.bashrc）
# -------------------------------
install() {
    if check_installed; then
        echo -e "${YELLOW}系统信息工具已安装，是否继续安装？${NC}"
        read -p "继续安装将卸载并重新安装，是否继续？[y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${YELLOW}已取消安装。${NC}"
            read -n 1 -s -r -p "按任意键返回菜单..."
            return
        else
            echo -e "${YELLOW}正在卸载旧版本...${NC}"
            uninstall
        fi
    fi

    mkdir -p ~/.local

    echo -e "${YELLOW}正在安装依赖工具...${NC}"
    install_dependencies

    if [[ -f /etc/motd ]]; then
        echo -e "${YELLOW}备份 /etc/motd 文件到 /etc/motd.bak...${NC}"
        sudo cp /etc/motd /etc/motd.bak
        sudo truncate -s 0 /etc/motd
        echo -e "${GREEN}备份完成，备份文件路径：/etc/motd.bak${NC}"
    fi

    echo -e "${YELLOW}正在创建系统信息脚本...${NC}"
    cat << 'EOF' > ~/.local/sysinfo.sh
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

# -------------------------------
# 进度条函数（显示内存和磁盘使用情况）
# -------------------------------
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

# -------------------------------
# 获取操作系统信息
# -------------------------------
os_info=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | sed 's/PRETTY_NAME=//;s/"//g')

# -------------------------------
# 获取系统运行时间
# -------------------------------
uptime_seconds=$(awk '{print $1}' /proc/uptime)
uptime_days=$(bc <<< "scale=0; $uptime_seconds / 86400")
uptime_hours=$(bc <<< "scale=0; ($uptime_seconds % 86400) / 3600")
uptime_minutes=$(bc <<< "scale=0; ($uptime_seconds % 3600) / 60")
uptime_info="${uptime_days} days, ${uptime_hours} hours, ${uptime_minutes} minutes"

# -------------------------------
# 获取 CPU 信息
# -------------------------------
cpu_info=$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//;s/CPU @.*//;s/^ *//;s/ *$//')
cpu_cores=$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print $2}')
load_info=$(awk '{print $1", "$2", "$3}' /proc/loadavg)

# -------------------------------
# 获取内存信息
# -------------------------------
memory_total=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
memory_used=$(free -m 2>/dev/null | awk '/Mem:/{print $3}')

# -------------------------------
# 获取 Swap 信息
# -------------------------------
swap_total=$(free -m 2>/dev/null | awk '/Swap:/{print $2}')
swap_used=$(free -m 2>/dev/null | awk '/Swap:/{print $3}')

# -------------------------------
# 获取磁盘信息
# -------------------------------
disk_total=$(df -k / 2>/dev/null | awk 'NR==2 {print $2}')
disk_used=$(df -k / 2>/dev/null | awk 'NR==2 {print $3}')

# -------------------------------
# 获取网络流量（默认网络接口）
# -------------------------------
get_network_traffic() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [[ -z "$interface" ]]; then
        interface="eth0"
    fi

    local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)

    format_bytes() {
        local bytes=$1
        if (( bytes >= 1099511627776 )); then
            awk "BEGIN {printf \"%.2f TB\", bytes/1099511627776}"
        elif (( bytes >= 1073741824 )); then
            awk "BEGIN {printf \"%.2f GB\", bytes/1073741824}"
        else
            awk "BEGIN {printf \"%.2f MB\", bytes/1048576}"
        fi
    }

    local rx_traffic=$(format_bytes $rx_bytes)
    local tx_traffic=$(format_bytes $tx_bytes)

    echo -e "${ORANGE}Traffic:${NC} ${BLUE}TX:${NC} ${YELLOW}$tx_traffic${NC}, ${BLUE}RX:${NC} ${GREEN}$rx_traffic${NC}"
}

# -------------------------------
# 获取并显示 IP 与 ASN/运营商信息（使用 ipinfo.io 查询）
# -------------------------------
get_ipinfo() {
    config_file="$HOME/.local/ipinfo_mode"
    mode="ipv4"
    if [[ -f "$config_file" ]]; then
        mode=$(cat "$config_file")
    else
        echo "ipv4" > "$config_file"
    fi

    if [[ "$mode" == "ipv4" ]]; then
        data=$(curl -s -4 "https://ipinfo.io/json?token=3b01046f048430")
    else
        data=$(curl -s -6 "https://ipinfo.io/json?token=3b01046f048430")
    fi

    ip=$(echo "$data" | grep -oP '"ip":\s*"\K[^"]+')
    org=$(echo "$data" | grep -oP '"org":\s*"\K[^"]+')
    asn=$(echo "$org" | awk '{print $1}')
    isp=$(echo "$org" | cut -d' ' -f2-)

    if [[ "$mode" == "ipv4" ]]; then
        echo -e "${GREEN}IPv4:${NC} $ip"
    else
        echo -e "${GREEN}IPv6:${NC} $ip"
    fi

    if [[ -n "$asn" && -n "$isp" ]]; then
        echo -e "${GREEN}$asn${NC} ${YELLOW}$isp${NC}"
    fi
}

# -------------------------------
# 显示系统所有信息
# -------------------------------
echo -e "${ORANGE}OS:${NC}        ${os_info:-N/A}"
echo -e "${ORANGE}Uptime:${NC}    ${uptime_info:-N/A}"
echo -e "${ORANGE}CPU:${NC}       ${cpu_info:-N/A} (${cpu_cores:-N/A} cores)"
echo -e "${ORANGE}Load:${NC}      ${load_info:-N/A}"

echo -ne "${ORANGE}Memory:${NC}    "
progress_bar $memory_used $memory_total
echo " ${memory_used:-N/A}MB / ${memory_total:-N/A}MB ($(awk "BEGIN {printf \"%.0f%%\", (\$memory_used/\$memory_total)*100}") )"

if [[ -n "$swap_total" && $swap_total -ne 0 ]]; then
    swap_usage=$(awk "BEGIN {printf \"%.0fMB / %.0fMB (%.0f%%)\", \$swap_used, \$swap_total, (\$swap_used/\$swap_total)*100}")
    echo -e "${ORANGE}Swap:${NC}      $swap_usage"
fi

echo -ne "${ORANGE}Disk:${NC}      "
progress_bar $disk_used $disk_total
echo " $(df -h / 2>/dev/null | awk 'NR==2 {print \$3 " / " \$2 " (" \$5 ")"}')"

get_network_traffic

# 最后获取并显示 IP 与 ASN/运营商信息
get_ipinfo
EOF

    chmod +x ~/.local/sysinfo.sh

    # -------------------------------
    # 在 ~/.bashrc 添加 SSH 登录时执行系统信息脚本
    # -------------------------------
    if ! grep -q 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' ~/.bashrc; then
        echo '# SYSINFO SSH LOGIC START' >> ~/.bashrc
        echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    # -------------------------------
    # 在 ~/.bashrc 末尾添加 Git 分支解析及 PS1 定制（仅添加一次）
    # -------------------------------
    if ! grep -q 'parse_git_branch()' ~/.bashrc; then
        echo '# GIT BRANCH AND PS1 CUSTOMIZATION START' >> ~/.bashrc
        echo 'parse_git_branch() {' >> ~/.bashrc
        echo '    git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/ (\1)/"' >> ~/.bashrc
        echo '}' >> ~/.bashrc
        echo "" >> ~/.bashrc
        echo "PS1='\[\033[01;38;5;117m\]\u\[\033[01;33m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[01;35m\]\$(parse_git_branch)\[\033[00m\] \[\033[01;36m\][\D{%H:%M:%S}]\[\033[00m\]\n\[\033[01;37m\]\$ \[\033[00m\]'" >> ~/.bashrc
        echo '# GIT BRANCH AND PS1 CUSTOMIZATION END' >> ~/.bashrc
    fi

    echo -e "${GREEN}系统信息工具安装完成！${NC}"
    echo -e "${YELLOW}默认显示 IPv4 的 ASN 运营商信息，可通过脚本切换显示。${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# -------------------------------
# 显示菜单，提供 安装、卸载、切换 IPv4/IPv6 ASN 信息显示模式、退出 等选项
# -------------------------------
show_menu() {
    while true; do
        clear
        echo -e "${ORANGE}=========================${NC}"
        echo -e "${ORANGE}请选择操作：${NC}"
        echo -e "${ORANGE}1. 安装 SSH 欢迎系统信息${NC}"
        echo -e "${ORANGE}2. 卸载脚本及系统信息${NC}"
        echo -e "${ORANGE}3. 切换 IPv4/IPv6 的 ASN 运营商显示${NC}"
        echo -e "${ORANGE}0. 退出脚本${NC}"
        echo -e "${ORANGE}当前状态：$(check_installed)${NC}"
        echo -e "${ORANGE}=========================${NC}"
        read -p "请输入选项 (0、1、2 或 3): " choice

        case $choice in
            1)
                install
                ;;
            2)
                uninstall
                read -n 1 -s -r -p "按任意键返回菜单..."
                ;;
            3)
                toggle_ipinfo_mode
                read -n 1 -s -r -p "按任意键返回菜单..."
                ;;
            0)
                echo -e "${ORANGE}退出脚本。${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"
                read -n 1 -s -r
                ;;
        esac
    done
}

# -------------------------------
# 主逻辑入口
# -------------------------------
show_menu
