#!/bin/bash

terminal_size=$(stty size)
rows=$(echo "$terminal_size" | awk '{print $1}')
cols=$(echo "$terminal_size" | awk '{print $2}')
if [ "$rows" -lt 50 ] || [ "$cols" -lt 120 ]; then
  stty rows 50 cols 120
fi

ORANGE='\033[1;38;5;208m'
GREEN='\033[1;32m'
BLACK='\033[0;30m'
RED='\033[1;31m'
ORANGE_START='\033[38;5;214m'
ORANGE_END='\033[38;5;208m'
NC='\033[0m'

echo -e "${ORANGE_START}============[ System Information ]============${NC}"

os_info=$(lsb_release -d 2>/dev/null | awk -F'\t' '{print $2}')
[ -z "$os_info" ] && os_info=$(cat /etc/os-release | grep PRETTY_NAME | awk -F'"' '{print $2}')
arch_info=$(uname -m)
virt_info=$(systemd-detect-virt 2>/dev/null || echo "Physical")
kernel_info=$(uname -r)
cpu_info=$(lscpu 2>/dev/null)
uptime_seconds=$(awk '{print $1}' /proc/uptime)
uptime_days=$((${uptime_seconds%.*}/86400))
uptime_hours=$((${uptime_seconds%.*}%86400/3600))
uptime_minutes=$((${uptime_seconds%.*}%3600/60))
uptime_info="${uptime_days} days ${uptime_hours} hours ${uptime_minutes} minutes"
memory_info=$(free -h)
disk_info=$(df -h /)
ipv4_info=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
[ -z "$ipv4_info" ] && ipv4_info=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
ipv6_info=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)
interface_info=$(ip route | grep default | awk '{print $5}' 2>/dev/null)

echo -e "${ORANGE}OS        : ${NC}$os_info ($arch_info $virt_info)"
echo -e "${ORANGE}Kernel    : ${NC}$kernel_info"

cpu_model=$(echo "$cpu_info" | grep -i 'model name' | head -n 1 | awk -F': ' '{print $2}' | sed 's/^[ \t]*//')
cpu_cores=$(echo "$cpu_info" | grep -i '^CPU(s):' | awk '{print $2}')
echo -e "${ORANGE}CPU       : ${NC}$cpu_model ($cpu_cores cores)"

echo -e "${ORANGE}Uptime    : ${NC}$uptime_info"

generate_bar() {
  local percent=$1
  awk -v p="$percent" 'BEGIN {
    for (i=1; i<=20; i++) {
      if (i <= p/5) {
        printf "\033[38;5;%dm=\033[0m", 28 + int(i * 3)
      } else {
        printf " "
      }
    }
  }'
}

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

  echo -e "${ORANGE}Memory    : ${NC}[$(generate_bar $memory_percent)] $(echo "$memory_info" | awk 'NR==2{print $3 "/" $2}') ($memory_percent%)"
  echo -e "${ORANGE}Swap      : ${NC}[$(generate_bar $swap_percent)] $(echo "$memory_info" | awk 'NR==3{print $3 "/" $2}') ($swap_percent%)"
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

  echo -e "${ORANGE}Memory    : ${NC}[$(generate_bar $memory_percent)] $(echo "$memory_info" | awk 'NR==2{print $3 "/" $2}') ($memory_percent%)"
fi

disk_used=$(echo "$disk_info" | awk 'NR==2{print $3}' | sed 's/[^0-9.]//g')
disk_total=$(echo "$disk_info" | awk 'NR==2{print $2}' | sed 's/[^0-9.]//g')
disk_percent=$(awk "BEGIN {printf \"%.1f\", ($disk_used/$disk_total)*100}")

echo -e "${ORANGE}Disk      : ${NC}[$(generate_bar $disk_percent)] $(echo "$disk_info" | awk 'NR==2{print $3 "/" $2}') ($disk_percent%)"

if [ -n "$ipv4_info" ]; then
  echo -e "${GREEN}IPv4      : ${NC}$ipv4_info"
  ip_info=$(curl -s --max-time 2 "https://ipinfo.io/$ipv4_info/json")
  ipv4_location=$(echo "$ip_info" | grep '"city":' | awk -F'"' '{print $4}')
  ipv4_isp=$(echo "$ip_info" | grep '"org":' | awk -F'"' '{print $4}')

  [ -n "$ipv4_isp" ] && echo -e "${ORANGE}Provider  : ${NC}$ipv4_isp" || echo -e "${ORANGE}Provider  : ${NC}N/A"
  [ -n "$ipv4_location" ] && echo -e "${ORANGE}Location  : ${NC}$ipv4_location" || echo -e "${ORANGE}Location  : ${NC}N/A"
fi

if [ -n "$ipv6_info" ]; then
  echo -e "${GREEN}IPv6      : ${NC}$ipv6_info"
  ip_info=$(curl -s --max-time 2 "https://ipinfo.io/$ipv6_info/json")
  ipv6_location=$(echo "$ip_info" | grep '"city":' | awk -F'"' '{print $4}')
  ipv6_isp=$(echo "$ip_info" | grep '"org":' | awk -F'"' '{print $4}')

  [ -n "$ipv6_isp" ] && echo -e "${ORANGE}Provider  : ${NC}$ipv6_isp" || echo -e "${ORANGE}Provider  : ${NC}N/A"
  [ -n "$ipv6_location" ] && echo -e "${ORANGE}Location  : ${NC}$ipv6_location" || echo -e "${ORANGE}Location  : ${NC}N/A"
fi

if [ -n "$interface_info" ]; then
  rx_bytes=$(cat /sys/class/net/$interface_info/statistics/rx_bytes 2>/dev/null)
  tx_bytes=$(cat /sys/class/net/$interface_info/statistics/tx_bytes 2>/dev/null)

  convert_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
      echo "${bytes} B"
    elif [ "$bytes" -lt $((1024 * 1024)) ]; then
      echo "$((bytes / 1024)) KB"
    elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
      echo "$((bytes / 1024 / 1024)) MB"
    else
      echo "$((bytes / 1024 / 1024 / 1024)) GB"
    fi
  }

  if [ -n "$rx_bytes" ] && [ -n "$tx_bytes" ]; then
    rx_converted=$(convert_bytes $rx_bytes)
    tx_converted=$(convert_bytes $tx_bytes)
    echo -e "${ORANGE}Traffic   : ${NC}${RED}Tx${NC}:${tx_converted} ${GREEN}Rx${NC}:${rx_converted}"
  else
    echo -e "${ORANGE}Traffic   : ${NC}N/A"
  fi
else
  echo -e "${ORANGE}Traffic   : ${NC}N/A"
fi

echo -e "${ORANGE_START}==============================================${NC}"

echo
echo
