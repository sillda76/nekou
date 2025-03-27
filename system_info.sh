#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
LIGHTGREEN='\033[1;92m'
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
        filled=$(( progress * bar_width / total ))
        empty=$(( bar_width - filled ))
    fi

    printf "["
    for (( i=0; i<filled; i++ )); do
        if (( i < filled / 3 )); then
            printf "${GREEN}=${NC}"
        elif (( i < 2 * filled / 3 )); then
            printf "${YELLOW}=${NC}"
        else
            printf "${RED}=${NC}"
        fi
    done
    for (( i=0; i<empty; i++ )); do
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
LIGHTGREEN='\033[1;92m'
NC='\033[0m'

# 从配置中读取 ASN 显示模式（默认使用 ipv4）
ASN_MODE=$(cat ~/.local/sysinfo_asn_mode 2>/dev/null)
if [[ -z "$ASN_MODE" ]]; then
    ASN_MODE="ipv4"
fi

progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=0
    local empty=0
    if [[ $total -gt 0 ]]; then
        filled=$(( progress * bar_width / total ))
        empty=$(( bar_width - filled ))
    fi
    printf "["
    for (( i=0; i<filled; i++ )); do
        if (( i < filled / 3 )); then
            printf "${GREEN}=${NC}"
        elif (( i < 2 * filled / 3 )); then
            printf "${YELLOW}=${NC}"
        else
            printf "${RED}=${NC}"
        fi
    done
    for (( i=0; i<empty; i++ )); do
        printf "${BLACK}=${NC}"
    done
    printf "]"
}

# 获取系统信息
os_info=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

# 计算 uptime（取整，提高性能）
uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
uptime_days=$(( uptime_seconds / 86400 ))
uptime_hours=$(( (uptime_seconds % 86400) / 3600 ))
uptime_minutes=$(( (uptime_seconds % 3600) / 60 ))
uptime_info="${uptime_days} days, ${uptime_hours} hours, ${uptime_minutes} minutes"

# CPU 信息
cpu_info=$(lscpu 2>/dev/null | grep -m 1 "Model name:" | awk -F: '{print $2}' | xargs | sed 's/CPU @.*//')
cpu_cores=$(lscpu 2>/dev/null | awk '/^CPU\(s\):/ {print $2}')
load_info=$(awk '{print $1", "$2", "$3}' /proc/loadavg)

# 内存、Swap 与磁盘信息
read memory_total memory_used < <(free -m 2>/dev/null | awk '/^Mem:/{print $2" "$3}')
read swap_total swap_used < <(free -m 2>/dev/null | awk '/^Swap:/{print $2" "$3}')
read disk_total disk_used <<< $(df -k / 2>/dev/null | awk 'NR==2 {print $2" "$3}')

# 检测所有非 loopback 网卡流量
get_network_traffic() {
    local total_rx=0
    local total_tx=0
    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        if [[ "$iface" == "lo" ]]; then
            continue
        fi
        rx=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null || echo 0)
        tx=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null || echo 0)
        total_rx=$(( total_rx + rx ))
        total_tx=$(( total_tx + tx ))
    done

    format_bytes() {
        local bytes=$1
        if (( bytes >= 1099511627776 )); then
            awk -v b=$bytes 'BEGIN {printf "%.2f TB", b / 1099511627776}'
        elif (( bytes >= 1073741824 )); then
            awk -v b=$bytes 'BEGIN {printf "%.2f GB", b / 1073741824}'
        else
            awk -v b=$bytes 'BEGIN {printf "%.2f MB", b / 1048576}'
        fi
    }

    local rx_traffic=$(format_bytes "$total_rx")
    local tx_traffic=$(format_bytes "$total_tx")

    echo -e "${ORANGE}Traffic:${NC} ${BLUE}TX:${NC} ${YELLOW}$tx_traffic${NC}, ${BLUE}RX:${NC} ${GREEN}$rx_traffic${NC}"
    echo -e "======================"
}

# 获取公网 IP 和 ASN 信息（使用 IPinfo）
get_ip_and_asn() {
    local response
    response=$(curl -s --max-time 3 "https://ipinfo.io/json?token=3b01046f048430")
    if [[ -z "$response" || "$response" == *"error"* ]]; then
        echo -e "${RED}Failed to fetch IP/ASN data${NC}"
        return
    fi

    local ipv4=$(echo "$response" | grep -oP '"ip":\s*"\K[^"]+' | head -1)
    local ipv6=$(echo "$response" | grep -oP '"ip6":\s*"\K[^"]+' || echo "")
    local org=$(echo "$response" | grep -oP '"org":\s*"\K[^"]+')

    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:${NC} $ipv4"
    fi
    if [[ -n "$ipv6" && "$ipv6" != "$ipv4" ]]; then
        echo -e "${GREEN}IPv6:${NC} $ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi

    if [[ -n "$org" ]]; then
        echo -e "${LIGHTGREEN}${org}${NC}"
    else
        echo -e "${RED}ASN Not found${NC}"
    fi
}

# 输出系统信息
echo -e "${ORANGE}OS:${NC}     ${os_info:-N/A}"
echo -e "${ORANGE}Uptime:${NC} ${uptime_info:-N/A}"
echo -e "${ORANGE}CPU:${NC}    ${cpu_info:-N/A} (${cpu_cores:-N/A} cores)"
echo -e "${ORANGE}Load:${NC}   ${load_info:-N/A}"
echo -ne "${ORANGE}Memory:${NC} "
progress_bar "$memory_used" "$memory_total"
mem_percent=$(awk -v used="$memory_used" -v total="$memory_total" 'BEGIN { if (total>0) printf "%.0f%%", (used/total)*100; else printf "N/A"}')
echo " ${memory_used:-N/A}MB / ${memory_total:-N/A}MB (${mem_percent})"
if [[ -n "$swap_total" && $swap_total -ne 0 ]]; then
    swap_usage=$(awk -v used="$swap_used" -v total="$swap_total" 'BEGIN { if (total>0) printf "%.0fMB / %.0fMB (%.0f%%)", used, total, (used/total)*100; else printf "0MB / 0MB (0%%)"}')
    echo -e "${ORANGE}Swap:${NC}   $swap_usage"
fi
echo -ne "${ORANGE}Disk:${NC}   "
progress_bar "$disk_used" "$disk_total"
disk_usage_info=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
echo " ${disk_usage_info}"
get_network_traffic
get_ip_and_asn
EOF

    chmod +x ~/.local/sysinfo.sh

    if ! grep -q 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' ~/.bashrc; then
        {
            echo '# SYSINFO SSH LOGIC START'
            echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then'
            echo '    bash ~/.local/sysinfo.sh'
            echo 'fi'
            echo '# SYSINFO SSH LOGIC END'
        } >> ~/.bashrc
    fi

    source ~/.bashrc >/dev/null 2>&1
    echo -e "${GREEN}系统信息工具安装完成！${NC}"
    echo -e "${YELLOW}系统信息脚本路径：~/.local/sysinfo.sh${NC}"
    echo -e "${YELLOW}提示：可通过交互菜单中的选项 2 切换 ASN 显示模式（IPv4/IPv6）。${NC}"
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
        if [[ "$current_asn_mode" == "ipv4" ]]; then
            display_asn_mode="IPv4"
        else
            display_asn_mode="IPv6"
        fi

        echo -e "${ORANGE} ==========================${NC}"
        echo -e "${ORANGE}请选择操作：${NC}"
        echo -e "${ORANGE}1. 安装 SSH 欢迎系统信息${NC}"
        echo -e "${ORANGE}2. 切换 ASN 显示模式 ${YELLOW}(当前: ${display_asn_mode})${NC}"
        echo -e "${ORANGE}3. 卸载脚本及系统信息${NC}"
        echo -e "${ORANGE}0. 退出脚本${NC}"
        echo -e "${ORANGE}当前状态：$(check_installed)${NC}"
        echo -e "${ORANGE} ==========================${NC}"
        read -p "请输入选项 (0、1、2 或 3): " choice

        case $choice in
            1)
                install
                ;;
            2)
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
