#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
GRAY='\033[1;37m'
NC='\033[0m' # 重置颜色

# 进度条函数（渐变配色）
progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=$(echo "($progress/$total)*$bar_width" | bc -l | awk '{printf "%d", $1}')
    local empty=$((bar_width - filled))

    printf "["
    for ((i=0; i<filled; i++)); do
        if ((i < filled / 2)); then
            printf "${GREEN}=${NC}" # 前半部分绿色
        else
            printf "${YELLOW}=${NC}" # 后半部分黄色
        fi
    done
    for ((i=0; i<empty; i++)); do printf "${GRAY}=${NC}"; done # 未完成部分灰色
    printf "]"
}

# 获取系统信息
os_info=$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')
uptime_info=$(uptime -p 2>/dev/null | sed 's/up //g')
cpu_info=$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | xargs)
cpu_cores=$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print $2}')
cpu_speed=$(lscpu 2>/dev/null | grep "CPU MHz" | awk '{print $3/1000 "GHz"}' | xargs)
memory_total=$(free -m 2>/dev/null | grep Mem: | awk '{print $2}')
memory_used=$(free -m 2>/dev/null | grep Mem: | awk '{print $3}')
swap_total=$(free -m 2>/dev/null | grep Swap: | awk '{print $2}')
swap_used=$(free -m 2>/dev/null | grep Swap: | awk '{print $3}')
disk_total=$(df -k / 2>/dev/null | grep / | awk '{print $2}')
disk_used=$(df -k / 2>/dev/null | grep / | awk '{print $3}')

# 显示系统信息
echo -e "${CYAN}OS:${NC}        ${os_info:-N/A}"
echo -e "${CYAN}Uptime:${NC}    ${uptime_info:-N/A}"
echo -e "${CYAN}CPU:${NC}       ${cpu_info:-N/A} @${cpu_speed:-N/A} (${cpu_cores:-N/A} cores)"
echo -ne "${CYAN}Memory:${NC}    "
progress_bar $memory_used $memory_total
echo " ${memory_used:-N/A}MB / ${memory_total:-N/A}MB ($(awk "BEGIN {printf \"%.0f%%\", ($memory_used/$memory_total)*100}"))"

# 如果 Swap 未开启，则不显示 Swap 信息
if [[ -n "$swap_total" && $swap_total -ne 0 ]]; then
    swap_usage=$(awk "BEGIN {printf \"%.0fMB / %.0fMB (%.0f%%)\", $swap_used, $swap_total, ($swap_used/$swap_total)*100}")
    echo -e "${CYAN}Swap:${NC}      $swap_usage"
fi

echo -ne "${CYAN}Disk:${NC}      "
progress_bar $disk_used $disk_total
echo " $(df -h / 2>/dev/null | grep / | awk '{print $3 " / " $2 " (" $5 ")"}')"

# 获取公网 IP 信息
get_public_ip() {
    ipv4=$(curl -s --max-time 3 ipv4.icanhazip.com 2>/dev/null)
    ipv6=$(curl -s --max-time 3 ipv6.icanhazip.com 2>/dev/null)

    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:${NC} $ipv4"
    fi
    if [[ -n "$ipv6" ]]; then
        echo -e "${GREEN}IPv6:${NC} $ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi
}

get_public_ip
sleep 0.05
echo -ne "\n"
