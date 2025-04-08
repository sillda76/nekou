#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
LIGHTGREEN='\033[1;92m'  # 浅绿色
LIGHTBLUE='\033[1;94m'   # 浅蓝色
LIGHTPURPLE='\033[1;35m' # 浅紫色
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
    local filled=0
    local empty=0

    if [[ $total -gt 0 ]]; then
        filled=$((progress * bar_width / total))
        empty=$((bar_width - filled))
    fi

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
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}未找到 bc 工具，正在安装...${NC}"
        sudo apt install bc -y || { echo -e "${RED}安装 bc 失败！${NC}"; exit 1; }
    fi
    sudo apt install net-tools curl -y || { echo -e "${RED}安装依赖失败！${NC}"; exit 1; }
}

# 修改后的公网 IP 获取（支持本地或外部获取）
# 此函数主要用于安装前检测和在安装脚本中打印 IP 信息
get_public_ip() {
    # 读取 IP 获取模式，默认 "local"
    local ip_mode
    ip_mode=$(cat ~/.local/sysinfo_ip_mode 2>/dev/null)
    if [[ -z "$ip_mode" ]]; then
        ip_mode="local"
    fi

    if [[ "$ip_mode" == "local" ]]; then
        # 本地获取：通过缺省网卡获取 IP 信息
        local default_iface
        default_iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
        ipv4=$(ip -4 addr show "$default_iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
        ipv6=$(ip -6 addr show "$default_iface" 2>/dev/null | grep -oP '(?<=inet6\s)[a-fA-F0-9:]+(?=/)' | head -n 1)
    else
        # 外部获取：依然使用外部服务查询
        ipv4=$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
        ipv6=$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)
    fi

    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:${NC} $ipv4"
    fi
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* && "$ipv6" != "$ipv4" ]]; then
        echo -e "${GREEN}IPv6:${NC} $ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi

    # 根据配置决定 ASN 查询使用的 IP（保留原有逻辑）
    local asn_ip=""
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* && "$ipv6" != "$ipv4" ]]; then
        if [[ "$ASN_MODE" == "ipv6" ]]; then
            asn_ip="$ipv6"
        else
            asn_ip="$ipv4"
        fi
    else
        asn_ip="$ipv4"
    fi
    get_asn_info "$asn_ip"
}

# 卸载函数
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

# 安装函数
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

    # 初始化 IP 获取模式为 local（本地获取）如果配置文件不存在
    if [[ ! -f ~/.local/sysinfo_ip_mode ]]; then
        echo "local" > ~/.local/sysinfo_ip_mode
    fi

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

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
LIGHTGREEN='\033[1;92m'
LIGHTBLUE='\033[1;94m'
LIGHTPURPLE='\033[1;35m'
NC='\033[0m'

# 读取 ASN 显示模式（默认使用 ipv4）
ASN_MODE=$(cat ~/.local/sysinfo_asn_mode 2>/dev/null)
if [[ -z "$ASN_MODE" ]]; then
    ASN_MODE="ipv4"
fi

# 读取 IP 获取模式（默认 local：本地获取）
IP_MODE=$(cat ~/.local/sysinfo_ip_mode 2>/dev/null)
if [[ -z "$IP_MODE" ]]; then
    IP_MODE="local"
fi

progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=0
    local empty=0

    if [[ $total -gt 0 ]]; then
        filled=$((progress * bar_width / total))
        empty=$((bar_width - filled))
    fi

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

os_info=$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')

uptime_seconds=$(cat /proc/uptime | awk '{print $1}')
uptime_days=$(bc <<< "scale=0; $uptime_seconds / 86400")
uptime_hours=$(bc <<< "scale=0; ($uptime_seconds % 86400) / 3600")
uptime_minutes=$(bc <<< "scale=0; ($uptime_seconds % 3600) / 60")
uptime_info="${uptime_days} days, ${uptime_hours} hours, ${uptime_minutes} minutes"

cpu_info=$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | sed 's/CPU @.*//g' | xargs)
cpu_cores=$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print $2}')
load_info=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')

memory_total=$(free -m 2>/dev/null | grep Mem: | awk '{print $2}')
memory_used=$(free -m 2>/dev/null | grep Mem: | awk '{print $3}')
swap_total=$(free -m 2>/dev/null | grep Swap: | awk '{print $2}')
swap_used=$(free -m 2>/dev/null | grep Swap: | awk '{print $3}')
disk_total=$(df -k / 2>/dev/null | grep / | awk '{print $2}')
disk_used=$(df -k / 2>/dev/null | grep / | awk '{print $3}')

get_network_traffic() {
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [[ -z "$interface" ]]; then
        interface="eth0"
    fi

    local rx_bytes tx_bytes
    rx_bytes=$(cat /sys/class/net/"$interface"/statistics/rx_bytes 2>/dev/null)
    tx_bytes=$(cat /sys/class/net/"$interface"/statistics/tx_bytes 2>/dev/null)
    [[ -z "$rx_bytes" ]] && rx_bytes=0
    [[ -z "$tx_bytes" ]] && tx_bytes=0

    format_bytes() {
        local bytes=$1
        if (( bytes >= 1099511627776 )); then
            echo "$(awk -v b=$bytes 'BEGIN {printf "%.2fTB", b / 1099511627776}')"
        elif (( bytes >= 1073741824 )); then
            echo "$(awk -v b=$bytes 'BEGIN {printf "%.2fGB", b / 1073741824}')"
        else
            echo "$(awk -v b=$bytes 'BEGIN {printf "%.2fMB", b / 1048576}')"
        fi
    }

    local rx_traffic tx_traffic
    rx_traffic=$(format_bytes "$rx_bytes")
    tx_traffic=$(format_bytes "$tx_bytes")

    echo -e "${LIGHTBLUE}Traffic:${NC} ${ORANGE}TX:${NC}${YELLOW}$tx_traffic${NC} ${LIGHTPURPLE}RX:${NC}${GREEN}$rx_traffic${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
}

echo -e "${LIGHTBLUE}OS:${NC}       ${os_info:-N/A}"
echo -e "${LIGHTBLUE}Uptime:${NC}   ${uptime_info:-N/A}"
echo -e "${LIGHTBLUE}CPU:${NC}      ${cpu_info:-N/A} (${cpu_cores:-N/A} cores)"
echo -e "${LIGHTBLUE}Load:${NC}     ${load_info:-N/A}"

# Memory 显示
echo -ne "${LIGHTBLUE}Memory:${NC}   "
progress_bar $memory_used $memory_total
mem_percent=$(awk -v used="$memory_used" -v total="$memory_total" 'BEGIN {
    if (total>0) printf "%.0f%%", (used/total)*100;
    else printf "N/A";
}')
echo " ${memory_used:-N/A}MB/${memory_total:-N/A}MB (${mem_percent})"

# Swap 显示
if [[ -n "$swap_total" && $swap_total -ne 0 ]]; then
    swap_usage=$(awk -v used="$swap_used" -v total="$swap_total" 'BEGIN {
        if (total>0) printf "%.0fMB/%.0fMB (%.0f%%)", used, total, (used/total)*100;
        else printf "0MB/0MB (0%%)";
    }')
    echo -e "${LIGHTBLUE}Swap:${NC}     $swap_usage"
fi

# Disk 显示
echo -ne "${LIGHTBLUE}Disk:${NC}     "
progress_bar $disk_used $disk_total
echo " $(df -h / 2>/dev/null | grep / | awk '{print $3"/"$2" ("$5")"}')"

# 调用系统流量信息函数，恢复显示流量统计
get_network_traffic

# 修改后的公网 IP 获取：根据 IP_MODE 决定使用本地还是外部获取方式
get_public_ip() {
    if [[ "$IP_MODE" == "local" ]]; then
        local default_iface
        default_iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
        ipv4=$(ip -4 addr show "$default_iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
        ipv6=$(ip -6 addr show "$default_iface" 2>/dev/null | grep -oP '(?<=inet6\s)[a-fA-F0-9:]+(?=/)' | head -n 1)
    else
        ipv4=$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
        ipv6=$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)
    fi

    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:${NC} $ipv4"
    fi
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* && "$ipv6" != "$ipv4" ]]; then
        echo -e "${GREEN}IPv6:${NC} $ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi

    # 根据配置决定 ASN 查询使用的 IP（保留原有逻辑）
    local asn_ip=""
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* && "$ipv6" != "$ipv4" ]]; then
        if [[ "$ASN_MODE" == "ipv6" ]]; then
            asn_ip="$ipv6"
        else
            asn_ip="$ipv4"
        fi
    else
        asn_ip="$ipv4"
    fi
    get_asn_info "$asn_ip"
}

get_asn_info() {
    local ip=$1
    if [[ -z "$ip" ]]; then
        echo -e "${RED}No IP available for ASN${NC}"
        return
    fi
    local response
    response=$(curl -s --max-time 3 "https://ipinfo.io/${ip}/json?token=3b01046f048430")
    local org
    org=$(echo "$response" | grep -oP '"org":\s*"\K[^"]+')
    if [[ -n "$org" ]]; then
        echo -e "${LIGHTGREEN}${org}${NC}"
    else
        echo -e "${RED}ASN Not found${NC}"
    fi
}

get_public_ip
EOF

    chmod +x ~/.local/sysinfo.sh

    # 将脚本自动执行逻辑写入 ~/.bashrc
    if ! grep -q 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' ~/.bashrc; then
        echo '# SYSINFO SSH LOGIC START' >> ~/.bashrc
        echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    source ~/.bashrc >/dev/null 2>&1
    echo -e "${GREEN}系统信息工具安装完成！${NC}"
    echo -e "${YELLOW}系统信息脚本路径：~/.local/sysinfo.sh${NC}"
    echo -e "${YELLOW}提示：可通过交互菜单中的选项 2 切换 ASN 显示模式（IPv4/IPv6）；选项 3 切换 IP 获取模式（本地/外部）。${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 显示菜单
show_menu() {
    while true; do
        clear
        current_asn_mode=$(cat ~/.local/sysinfo_asn_mode 2>/dev/null)
        if [[ -z "$current_asn_mode" ]]; then
            current_asn_mode="ipv4"
        fi
        # 读取当前 IP 获取模式
        current_ip_mode=$(cat ~/.local/sysinfo_ip_mode 2>/dev/null)
        if [[ -z "$current_ip_mode" ]]; then
            current_ip_mode="local"
        fi

        # 根据当前模式设置显示文字
        if [[ "$current_asn_mode" == "ipv4" ]]; then
            display_asn_mode="IPv4"
        else
            display_asn_mode="IPv6"
        fi

        if [[ "$current_ip_mode" == "local" ]]; then
            display_ip_mode="本地获取"
        else
            display_ip_mode="外部获取"
        fi

        echo -e "${ORANGE}━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${ORANGE}请选择操作：${NC}"
        echo -e "${ORANGE}1. 安装 SSH 欢迎系统信息${NC}"
        echo -e "${ORANGE}2. 切换 ASN 显示模式 ${YELLOW}(当前: ${display_asn_mode})${NC}"
        echo -e "${ORANGE}3. 切换 IP 获取模式 ${YELLOW}(当前: ${display_ip_mode})${NC}"
        echo -e "${ORANGE}4. 卸载脚本及系统信息${NC}"
        echo -e "${ORANGE}0. 退出脚本${NC}"
        echo -e "${ORANGE}当前状态：$(check_installed)${NC}"
        echo -e "${ORANGE}━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "请输入选项 (0、1、2、3 或 4): " choice

        case $choice in
            1)
                install
                ;;
            2)
                # 切换 ASN 模式
                if [[ "$current_asn_mode" == "ipv4" ]]; then
                    new_mode="ipv6"
                    new_display_mode="IPv6"
                else
                    new_mode="ipv4"
                    new_display_mode="IPv4"
                fi
                echo "$new_mode" > ~/.local/sysinfo_asn_mode
                echo -e "${YELLOW}ASN 显示模式已切换为 ${new_display_mode}${NC}"
                read -n 1 -s -r -p "按任意键返回菜单..."
                ;;
            3)
                # 切换 IP 获取模式
                if [[ "$current_ip_mode" == "local" ]]; then
                    new_ip_mode="external"
                    new_ip_mode_disp="外部获取"
                else
                    new_ip_mode="local"
                    new_ip_mode_disp="本地获取"
                fi
                echo "$new_ip_mode" > ~/.local/sysinfo_ip_mode
                echo -e "${YELLOW}IP 获取模式已切换为 ${new_ip_mode_disp}${NC}"
                read -n 1 -s -r -p "按任意键返回菜单..."
                ;;
            4)
                uninstall
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

# 主逻辑
show_menu
