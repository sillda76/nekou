#!/bin/bash

# 动态调整终端大小
rows=$(stty size | awk '{print $1}')
cols=$(stty size | awk '{print $2}')
if [ "$rows" -lt 50 ] || [ "$cols" -lt 120 ]; then
  stty rows 50 cols 120
fi

# 定义颜色变量
ORANGE='\033[1;38;5;208m'  # 橙色（加粗）
GREEN='\033[1;32m'         # 绿色（加粗）
NC='\033[0m'               # 重置颜色

# 输出系统信息标题
echo -e "${ORANGE}============[ System Information ]============${NC}"

# 缓存命令结果
os_info=$(lsb_release -d 2>/dev/null | awk -F'\t' '{print $2}')  # 获取操作系统信息，兼容非 Ubuntu 系统
if [ -z "$os_info" ]; then
  os_info=$(cat /etc/os-release | grep PRETTY_NAME | awk -F'"' '{print $2}')  # 备用方法获取 OS 信息
fi
arch_info=$(uname -m)  # 获取系统架构
virt_info=$(systemd-detect-virt 2>/dev/null || echo "Physical")  # 检测虚拟化类型，若无则默认为物理机
kernel_info=$(uname -r)  # 获取内核版本
cpu_info=$(lscpu 2>/dev/null)  # 获取 CPU 信息
uptime_seconds=$(awk '{print $1}' /proc/uptime)  # 从 /proc/uptime 获取在线时间（秒）
uptime_days=$((${uptime_seconds%.*}/86400))  # 计算天数
uptime_hours=$((${uptime_seconds%.*}%86400/3600))  # 计算小时数
uptime_minutes=$((${uptime_seconds%.*}%3600/60))  # 计算分钟数
uptime_info="${uptime_days} days ${uptime_hours} hours ${uptime_minutes} minutes"  # 格式化在线时间
memory_info=$(free -h)  # 获取内存信息
disk_info=$(df -h /)  # 获取磁盘使用情况
ipv4_info=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)  # 获取公网 IPv4 地址
if [ -z "$ipv4_info" ]; then
  ipv4_info=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)  # 获取内网 IPv4 地址
fi
ipv6_info=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)  # 获取 IPv6 地址
interface_info=$(ip route | grep default | awk '{print $5}' 2>/dev/null)  # 获取默认网络接口

# 输出系统信息
echo -e "${ORANGE}OS        : ${NC}$os_info"
echo -e "${ORANGE}Arch      : ${NC}$arch_info $virt_info"
echo -e "${ORANGE}Kernel    : ${NC}$kernel_info"

# CPU 信息
cpu_model=$(echo "$cpu_info" | grep -i 'model name' | head -n 1 | awk -F': ' '{print $2}' | sed 's/^[ \t]*//')  # 提取 CPU 型号
cpu_cores=$(echo "$cpu_info" | grep -i '^CPU(s):' | awk '{print $2}')  # 提取 CPU 核心数
echo -e "${ORANGE}CPU       : ${NC}$cpu_model ($cpu_cores cores)"

# 系统负载
load=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ *//')  # 获取系统负载
echo -e "${ORANGE}Load      : ${NC}$load"

# 在线时间（格式化为“days hours minutes”）
echo -e "${ORANGE}Uptime    : ${NC}$uptime_info"

# 内存使用情况
echo -e "${ORANGE}Memory    : ${NC}$(echo "$memory_info" | awk 'NR==2{print $3 "/" $2 " (Used/Total)"}')"

# Swap 使用情况
if swapon --show | grep -q '^'; then
  echo -e "${ORANGE}Swap      : ${NC}$(echo "$memory_info" | awk 'NR==3{print $3 "/" $2 " (Used/Total)"}')"
fi

# 磁盘使用情况
echo -e "${ORANGE}Disk      : ${NC}$(echo "$disk_info" | awk 'NR==2{print $3 " used, " $2 " total"}')"

# 获取 IPv4 地理位置和运营商信息
if [ -n "$ipv4_info" ]; then
  echo -e "${GREEN}IPv4      : ${NC}$ipv4_info"  # IPv4 标题改为绿色
  ip_info=$(curl -s --max-time 2 "https://ipinfo.io/$ipv4_info/json")  # 使用 ipinfo.io 查询 IP 信息
  ipv4_location=$(echo "$ip_info" | grep '"city":' | awk -F'"' '{print $4}')  # 提取城市
  ipv4_isp=$(echo "$ip_info" | grep '"org":' | awk -F'"' '{print $4}')  # 提取运营商

  # 输出地理位置
  if [ -n "$ipv4_location" ]; then
    echo -e "${ORANGE}Location  : ${NC}$ipv4_location"
  else
    echo -e "${ORANGE}Location  : ${NC}N/A"
  fi

  # 输出运营商
  if [ -n "$ipv4_isp" ]; then
    echo -e "${ORANGE}Provider  : ${NC}$ipv4_isp"
  else
    echo -e "${ORANGE}Provider  : ${NC}N/A"
  fi
fi

# 获取 IPv6 地理位置和运营商信息
if [ -n "$ipv6_info" ]; then
  echo -e "${GREEN}IPv6      : ${NC}$ipv6_info"  # IPv6 标题改为绿色
  ip_info=$(curl -s --max-time 2 "https://ipinfo.io/$ipv6_info/json")  # 使用 ipinfo.io 查询 IP 信息
  ipv6_location=$(echo "$ip_info" | grep '"city":' | awk -F'"' '{print $4}')  # 提取城市
  ipv6_isp=$(echo "$ip_info" | grep '"org":' | awk -F'"' '{print $4}')  # 提取运营商

  # 输出地理位置
  if [ -n "$ipv6_location" ]; then
    echo -e "${ORANGE}Location  : ${NC}$ipv6_location"
  else
    echo -e "${ORANGE}Location  : ${NC}N/A"
  fi

  # 输出运营商
  if [ -n "$ipv6_isp" ]; then
    echo -e "${ORANGE}Provider  : ${NC}$ipv6_isp"
  else
    echo -e "${ORANGE}Provider  : ${NC}N/A"
  fi
fi

# 网络接口流量统计
if [ -n "$interface_info" ]; then
  rx_bytes=$(cat /sys/class/net/$interface_info/statistics/rx_bytes 2>/dev/null)  # 接收字节数
  tx_bytes=$(cat /sys/class/net/$interface_info/statistics/tx_bytes 2>/dev/null)  # 发送字节数

  # 字节转换函数
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
    echo -e "${ORANGE}Traffic   : ${NC}$(convert_bytes $tx_bytes) Tx, $(convert_bytes $rx_bytes) Rx"
  else
    echo -e "${ORANGE}Traffic   : ${NC}N/A"
  fi
else
  echo -e "${ORANGE}Traffic   : ${NC}N/A"
fi

# 输出结束行
echo -e "${ORANGE}==============================================${NC}"

# 添加两条空行，确保输出完整
echo
echo
