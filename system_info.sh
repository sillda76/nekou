#!/bin/bash

# 定义颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
NC='\033[0m'

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

# 获取总流量信息
get_total_traffic() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [[ -z "$interface" ]]; then
        echo -e "${ORANGE}Upload: N/A  Download: N/A${NC}"
        return
    fi

    local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
    local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null)

    if [[ -z "$rx_bytes" || -z "$tx_bytes" ]]; then
        echo -e "${ORANGE}Upload: N/A  Download: N/A${NC}"
        return
    fi

    # 字节转换为友好单位
    format_bytes() {
        local bytes=$1
        if (( bytes >= 1024**3 )); then
            echo "$(awk "BEGIN {printf \"%.0f GB\", $bytes / (1024**3)}")"
        elif (( bytes >= 1024**2 )); then
            echo "$(awk "BEGIN {printf \"%.0f MB\", $bytes / (1024**2)}")"
        elif (( bytes >= 1024 )); then
            echo "$(awk "BEGIN {printf \"%.0f KB\", $bytes / 1024}")"
        else
            echo "${bytes} B"
        fi
    }

    local upload=$(format_bytes $tx_bytes)
    local download=$(format_bytes $rx_bytes)

    echo -e "${ORANGE}Upload: ${upload}  Download: ${download}${NC}"
}

# 获取系统信息
os_info=$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')
uptime_info=$(uptime -p 2>/dev/null | sed 's/up //g')
cpu_info=$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | sed 's/CPU @.*//g' | xargs)
cpu_cores=$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print $2}')
memory_total=$(free -m 2>/dev/null | grep Mem: | awk '{print $2}')
memory_used=$(free -m 2>/dev/null | grep Mem: | awk '{print $3}')
swap_total=$(free -m 2>/dev/null | grep Swap: | awk '{print $2}')
swap_used=$(free -m 2>/dev/null | grep Swap: | awk '{print $3}')
disk_total=$(df -k / 2>/dev/null | grep / | awk '{print $2}')
disk_used=$(df -k / 2>/dev/null | grep / | awk '{print $3}')

# 显示系统信息
echo -e "${ORANGE}System:   ${NC}${os_info:-N/A}"
echo -e "${ORANGE}Uptime:   ${NC}${uptime_info:-N/A}"
echo -e "${ORANGE}CPU:      ${NC}${cpu_info:-N/A} (${cpu_cores:-N/A} cores)"

# 显示内存使用情况
echo -ne "${ORANGE}Mem:      ${NC}"
progress_bar $memory_used $memory_total
echo " ${memory_used:-N/A}MB / ${memory_total:-N/A}MB ($(awk "BEGIN {printf \"%.0f%%\", ($memory_used/$memory_total)*100}"))"

# 显示交换分区使用情况
if [[ -n "$swap_total" && $swap_total -ne 0 ]]; then
    swap_usage=$(awk "BEGIN {printf \"%.0fMB / %.0fMB (%.0f%%)\", $swap_used, $swap_total, ($swap_used/$swap_total)*100}")
    echo -e "${ORANGE}Swap:     ${NC}$swap_usage"
fi

# 显示磁盘使用情况
echo -ne "${ORANGE}Disk:     ${NC}"
progress_bar $disk_used $disk_total
echo " $(df -h / 2>/dev/null | grep / | awk '{print $3 " / " $2 " (" $5 ")"}')"

# 显示总流量信息
get_total_traffic

# 获取公网 IP 信息
get_public_ip() {
    ipv4=$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
    ipv6=$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)

    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:     ${NC}$ipv4"
    fi
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* && "$ipv6" != "$ipv4" ]]; then
        echo -e "${GREEN}IPv6:     ${NC}$ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi
}

get_public_ip
