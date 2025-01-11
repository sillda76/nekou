#!/bin/bash

install() {
    # 创建 ~/.local 目录
    mkdir -p ~/.local

    # 备份并清空 /etc/motd
    sudo cp /etc/motd /etc/motd.bak
    sudo truncate -s 0 /etc/motd

    # 创建系统信息脚本
    cat << 'EOF' > ~/.local/sysinfo.sh
#!/bin/bash

# 检查终端大小并调整
terminal_size=$(stty size)
rows=$(echo "$terminal_size" | awk '{print $1}')
cols=$(echo "$terminal_size" | awk '{print $2}')

if [ "$rows" -lt 50 ] || [ "$cols" -lt 120 ]; then
  stty rows 50 cols 120
fi

# 短暂延迟以确保终端初始化
sleep 0.5

# 定义颜色变量
ORANGE='\033[1;38;5;208m'
GREEN='\033[1;32m'
RED='\033[1;31m'
ORANGE_START='\033[38;5;214m'
NC='\033[0m'

# 显示系统信息标题
echo -e "${ORANGE_START}============[ System Information ]============${NC}"

# 获取操作系统信息
os_info=$(lsb_release -d 2>/dev/null | awk -F'\t' '{print $2}')
[ -z "$os_info" ] && os_info=$(cat /etc/os-release | grep PRETTY_NAME | awk -F'"' '{print $2}')
arch_info=$(uname -m)
virt_info=$(systemd-detect-virt 2>/dev/null || echo "Physical")
kernel_info=$(uname -r)

# 获取 CPU 信息
cpu_info=$(lscpu 2>/dev/null)
cpu_model=$(echo "$cpu_info" | grep -i 'model name' | head -n 1 | awk -F': ' '{print $2}' | sed 's/^[ \t]*//')
cpu_cores=$(echo "$cpu_info" | grep -i '^CPU(s):' | awk '{print $2}')

# 获取系统运行时间
uptime_seconds=$(awk '{print $1}' /proc/uptime)
uptime_days=$((${uptime_seconds%.*}/86400))
uptime_hours=$((${uptime_seconds%.*}%86400/3600))
uptime_minutes=$((${uptime_seconds%.*}%3600/60))
uptime_info="${uptime_days} days ${uptime_hours} hours ${uptime_minutes} minutes"

# 获取内存和交换分区信息
memory_info=$(free -h)
disk_info=$(df -h /)

# 获取 IP 信息
ipv4_info=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
[ -z "$ipv4_info" ] && ipv4_info=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
ipv6_info=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# 获取网络接口信息
interface_info=$(ip route | grep default | awk '{print $5}' 2>/dev/null)

# 显示操作系统信息
echo -e "${ORANGE}OS        : ${NC}$os_info ($arch_info $virt_info)"
echo -e "${ORANGE}Kernel    : ${NC}$kernel_info"
echo -e "${ORANGE}CPU       : ${NC}$cpu_model ($cpu_cores cores)"
echo -e "${ORANGE}Uptime    : ${NC}$uptime_info"

# 进度条函数
progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=$(echo "($progress/$total)*$bar_width" | bc -l | awk '{printf "%d", $1}')
    local empty=$((bar_width - filled))

    printf "["
    for ((i=0; i<filled; i++)); do printf "${RED}=${NC}"; done
    for ((i=0; i<empty; i++)); do printf "${GREEN}=${NC}"; done
    printf "]"
}

# 显示内存使用情况
if swapon --show | grep -q '^'; then
  memory_used=$(echo "$memory_info" | awk 'NR==2{print $3}' | sed 's/[^0-9.]//g')
  memory_total=$(echo "$memory_info" | awk 'NR==2{print $2}' | sed 's/[^0-9.]//g')
  
  if echo "$memory_info" | awk 'NR==2{print $2}' | grep -q 'Gi'; then
    memory_total=$(awk "BEGIN {printf \"%.1f\", $memory_total * 1024}")
  fi
  if echo "$memory_info" | awk 'NR==2{print $3}' | grep -q 'Gi'; then
    memory_used=$(awk "BEGIN {printf \"%.1f\", $memory_used * 1024}")
  fi

  memory_percent=$(awk "BEGIN {printf \"%.1f\", ($memory_used/$memory_total)*100}")
  swap_used=$(echo "$memory_info" | awk 'NR==3{print $3}' | sed 's/[^0-9.]//g')
  swap_total=$(echo "$memory_info" | awk 'NR==3{print $2}' | sed 's/[^0-9.]//g')
  swap_percent=$(awk "BEGIN {printf \"%.1f\", ($swap_used/$swap_total)*100}")

  echo -ne "${ORANGE}Memory    : ${NC}"
  progress_bar $memory_used $memory_total
  echo " $(echo "$memory_info" | awk 'NR==2{print $3 "/" $2}') ($memory_percent%)"

  echo -ne "${ORANGE}Swap      : ${NC}"
  progress_bar $swap_used $swap_total
  echo " $(echo "$memory_info" | awk 'NR==3{print $3 "/" $2}') ($swap_percent%)"
else
  memory_used=$(echo "$memory_info" | awk 'NR==2{print $3}' | sed 's/[^0-9.]//g')
  memory_total=$(echo "$memory_info" | awk 'NR==2{print $2}' | sed 's/[^0-9.]//g')

  if echo "$memory_info" | awk 'NR==2{print $2}' | grep -q 'Gi'; then
    memory_total=$(awk "BEGIN {printf \"%.1f\", $memory_total * 1024}")
  fi
  if echo "$memory_info" | awk 'NR==2{print $3}' | grep -q 'Gi'; then
    memory_used=$(awk "BEGIN {printf \"%.1f\", $memory_used * 1024}")
  fi

  memory_percent=$(awk "BEGIN {printf \"%.1f\", ($memory_used/$memory_total)*100}")

  echo -ne "${ORANGE}Memory    : ${NC}"
  progress_bar $memory_used $memory_total
  echo " $(echo "$memory_info" | awk 'NR==2{print $3 "/" $2}') ($memory_percent%)"
fi

# 显示磁盘使用情况
disk_used=$(echo "$disk_info" | awk 'NR==2{print $3}' | sed 's/[^0-9.]//g')
disk_total=$(echo "$disk_info" | awk 'NR==2{print $2}' | sed 's/[^0-9.]//g')
disk_percent=$(awk "BEGIN {printf \"%.1f\", ($disk_used/$disk_total)*100}")

echo -ne "${ORANGE}Disk      : ${NC}"
progress_bar $disk_used $disk_total
echo " $(echo "$disk_info" | awk 'NR==2{print $3 "/" $2}') ($disk_percent%)"

# 显示 IPv4 信息
if [ -n "$ipv4_info" ]; then
  echo -e "${GREEN}IPv4      : ${NC}$ipv4_info"
  ip_info=$(curl -s --max-time 2 "https://ipinfo.io/$ipv4_info/json")
  ipv4_location=$(echo "$ip_info" | grep '"city":' | awk -F'"' '{print $4}')
  ipv4_isp=$(echo "$ip_info" | grep '"org":' | awk -F'"' '{print $4}')

  [ -n "$ipv4_isp" ] && echo -e "${ORANGE}Provider  : ${NC}$ipv4_isp" || echo -e "${ORANGE}Provider  : ${NC}N/A"
  [ -n "$ipv4_location" ] && echo -e "${ORANGE}Location  : ${NC}$ipv4_location" || echo -e "${ORANGE}Location  : ${NC}N/A"
fi

# 显示 IPv6 信息
if [ -n "$ipv6_info" ]; then
  echo -e "${GREEN}IPv6      : ${NC}$ipv6_info"
  ip_info=$(curl -s --max-time 2 "https://ipinfo.io/$ipv6_info/json")
  ipv6_location=$(echo "$ip_info" | grep '"city":' | awk -F'"' '{print $4}')
  ipv6_isp=$(echo "$ip_info" | grep '"org":' | awk -F'"' '{print $4}')

  [ -n "$ipv6_isp" ] && echo -e "${ORANGE}Provider  : ${NC}$ipv6_isp" || echo -e "${ORANGE}Provider  : ${NC}N/A"
  [ -n "$ipv6_location" ] && echo -e "${ORANGE}Location  : ${NC}$ipv6_location" || echo -e "${ORANGE}Location  : ${NC}N/A"
fi

# 显示网络流量信息
if [ -n "$interface_info" ]; then
  rx_bytes=$(cat /sys/class/net/$interface_info/statistics/rx_bytes 2>/dev/null)
  tx_bytes=$(cat /sys/class/net/$interface_info/statistics/tx_bytes 2>/dev/null)

  convert_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
      echo "${bytes} B"
    elif [ "$bytes" -lt $((1024 * 1024)) ]; then
      echo "$(awk "BEGIN {printf \"%.2f\", $bytes / 1024}") KB"
    elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
      echo "$(awk "BEGIN {printf \"%.2f\", $bytes / 1024 / 1024}") MB"
    else
      echo "$(awk "BEGIN {printf \"%.2f\", $bytes / 1024 / 1024 / 1024}") GB"
    fi
  }

  if [ -n "$rx_bytes" ] && [ -n "$tx_bytes" ]; then
    rx_converted=$(convert_bytes $rx_bytes)
    tx_converted=$(convert_bytes $tx_bytes)
    echo -e "${ORANGE}Traffic   : ${NC}${RED}↑${NC}:${tx_converted} ${GREEN}↓${NC}:${rx_converted}"
  else
    echo -e "${ORANGE}Traffic   : ${NC}N/A"
  fi
else
  echo -e "${ORANGE}Traffic   : ${NC}N/A"
fi

# 强制刷新输出
echo
echo
EOF

    # 赋予执行权限
    chmod +x ~/.local/sysinfo.sh

    # 添加到 .bashrc
    if ! grep -q 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' ~/.bashrc; then
        echo '# SYSINFO SSH LOGIC START' >> ~/.bashrc
        echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    echo "安装完成！系统信息将在下次SSH登录时显示。"
    echo -e "\033[31m如需卸载，请运行：\033[0m bash <(wget -qO- https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/system_info.sh) -u"
}

uninstall() {
    # 删除系统信息脚本
    rm -f ~/.local/sysinfo.sh

    # 从 .bashrc 中移除相关逻辑
    sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc

    # 恢复 /etc/motd
    if [[ -f /etc/motd.bak ]]; then
      sudo mv /etc/motd.bak /etc/motd
    fi

    echo "卸载完成！"
}

# 主逻辑
if [ "$1" == "-u" ]; then
    uninstall
else
    install
fi
