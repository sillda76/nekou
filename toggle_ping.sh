#!/bin/bash

CONFIG_FILE="/etc/sysctl.conf"

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m' # 亮绿色
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m' # 青色
PURPLE='\033[0;35m' # 紫色
ORANGE='\033[0;33m' # 橙色
NC='\033[0m' # 恢复默认颜色

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请以root用户运行此脚本${NC}"
  exit 1
fi

# 获取本机 IP 地址
get_ip_address() {
  echo -e "${BLUE}========== 本机 IP 地址 ==========${NC}"
  
  # 获取 IPv4 地址
  ipv4_address=$(curl -s https://api.ipify.org || echo "")
  if [ -n "$ipv4_address" ]; then
    echo -e "${GREEN}IPv4: $ipv4_address${NC}"
  fi

  # 获取 IPv6 地址
  ipv6_address=$(curl -s https://icanhazip.com || curl -s https://ifconfig.co || echo "")
  # 检查是否为有效的 IPv6 地址
  if [[ "$ipv6_address" =~ ^[0-9a-fA-F:]+$ ]]; then
    echo -e "${CYAN}IPv6: $ipv6_address${NC}"
  else
    ipv6_address="" # 如果不是有效的 IPv6 地址，则清空
  fi

  if [ -z "$ipv4_address" ] && [ -z "$ipv6_address" ]; then
    echo -e "${YELLOW}未检测到有效的 IPv4 或 IPv6 地址。${NC}"
  fi
  echo -e "${BLUE}================================${NC}"
}

# 显示菜单
show_menu() {
  get_ip_address
  echo -e "${BLUE}============================${NC}"
  echo -e "${PURPLE}请选择要执行的操作：${NC}"
  echo -e "${RED}1. IPv4 禁 Ping 状态 (当前状态: $(get_ipv4_ping_status))${NC}"
  echo -e "${GREEN}2. IPv6 禁 Ping 状态 (当前状态: $(get_ipv6_ping_status))${NC}"
  echo -e "${CYAN}3. 查看当前 sysctl 配置${NC}"
  echo -e "${ORANGE}0. 退出脚本${NC}"
  echo -e "${BLUE}============================${NC}"
}

# 获取 IPv4 Ping 状态
get_ipv4_ping_status() {
  if ! ip -4 route &> /dev/null; then
    echo -e "${YELLOW}无 IPv4${NC}"
  elif grep -q "^net.ipv4.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo -e "${RED}已启用${NC}"
  else
    echo -e "${LIGHT_GREEN}未启用${NC}"
  fi
}

# 获取 IPv6 Ping 状态
get_ipv6_ping_status() {
  if ! ip -6 route &> /dev/null; then
    echo -e "${YELLOW}无 IPv6${NC}"
  elif grep -q "^net.ipv6.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo -e "${RED}已启用${NC}"
  else
    echo -e "${LIGHT_GREEN}未启用${NC}"
  fi
}

# 设置/恢复 IPv4 Ping
toggle_ipv4_ping() {
  if ! ip -4 route &> /dev/null; then
    echo -e "${RED}错误：未检测到 IPv4 网络。${NC}"
    return 1
  fi

  if grep -q "^net.ipv4.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo -e "${GREEN}正在恢复 IPv4 Ping...${NC}"
    sed -i 's/^net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo -e "${RED}正在设置 IPv4 禁 Ping...${NC}"
    sed -i '/^net.ipv4.icmp_echo_ignore_all/d' "$CONFIG_FILE"
    echo "net.ipv4.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

  echo -e "${BLUE}使配置生效...${NC}"
  if ! sysctl -p; then
    echo -e "${RED}错误：无法应用配置。${NC}"
    return 1
  fi
  echo -e "IPv4 Ping 状态已更新：$(get_ipv4_ping_status)"
}

# 设置/恢复 IPv6 Ping
toggle_ipv6_ping() {
  if ! ip -6 route &> /dev/null; then
    echo -e "${RED}错误：未检测到 IPv6 网络。${NC}"
    return 1
  fi

  if grep -q "^net.ipv6.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo -e "${GREEN}正在恢复 IPv6 Ping...${NC}"
    sed -i 's/^net.ipv6.icmp_echo_ignore_all=1/net.ipv6.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo -e "${RED}正在设置 IPv6 禁 Ping...${NC}"
    sed -i '/^net.ipv6.icmp_echo_ignore_all/d' "$CONFIG_FILE"
    echo "net.ipv6.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

  echo -e "${BLUE}使配置生效...${NC}"
  if ! sysctl -p; then
    echo -e "${RED}错误：无法应用配置。${NC}"
    return 1
  fi
  echo -e "IPv6 Ping 状态已更新：$(get_ipv6_ping_status)"
}

# 查看当前 sysctl 配置
view_sysctl_config() {
  echo -e "${BLUE}当前的 sysctl 配置文件内容如下：${NC}"
  echo -e "${BLUE}----------------------------------${NC}"
  cat "$CONFIG_FILE"
  echo -e "${BLUE}----------------------------------${NC}"
}

# 主循环
while true; do
  show_menu
  read -p "请输入选项: " choice
  case $choice in
    1)
      toggle_ipv4_ping
      ;;
    2)
      toggle_ipv6_ping
      ;;
    3)
      view_sysctl_config
      ;;
    0)
      echo -e "${ORANGE}退出脚本...${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}错误：无效选项，请按任意键返回菜单...${NC}"
      read -n 1 -s  # 等待用户按任意键
      continue
      ;;
  esac

  # 提示按任意键返回菜单
  read -n 1 -s -r -p "$(echo -e ${BLUE}操作完成，按任意键返回菜单...${NC})"
  echo
done
