#!/bin/bash

CONFIG_FILE="/etc/sysctl.conf"

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请以root用户运行此脚本${NC}"
  exit 1
fi

# 获取本机公网 IPv4 地址
get_public_ipv4() {
  local ipv4_address=$(curl -s https://api.ipify.org)
  if [ -z "$ipv4_address" ]; then
    echo "无 IPv4"
  else
    echo "$ipv4_address"
  fi
}

# 获取本机公网 IPv6 地址
get_public_ipv6() {
  local ipv6_address=$(curl -s https://api64.ipify.org)
  if [ -z "$ipv6_address" ]; then
    echo "无 IPv6"
  else
    echo "$ipv6_address"
  fi
}

# 获取当前禁 Ping 状态
get_icmp_status() {
  local ip_version=$1
  local config_key="net.${ip_version}.icmp_echo_ignore_all"
  local status=$(grep "^${config_key}=" "$CONFIG_FILE" 2>/dev/null | awk -F= '{print $2}')
  
  if [ "$status" == "1" ]; then
    echo -e "${RED}已启用${NC}"
  else
    echo -e "${GREEN}未启用${NC}"
  fi
}

# 显示菜单
show_menu() {
  # 获取本机公网 IPv4 和 IPv6 地址
  ipv4_address=$(get_public_ipv4)
  ipv6_address=$(get_public_ipv6)

  # 获取当前 IPv4 和 IPv6 的禁 Ping 状态
  if [ "$ipv4_address" != "无 IPv4" ]; then
    ipv4_status=$(get_icmp_status "ipv4")
  else
    ipv4_status="无 IPv4"
  fi

  if [ "$ipv6_address" != "无 IPv6" ]; then
    ipv6_status=$(get_icmp_status "ipv6")
  else
    ipv6_status="无 IPv6"
  fi

  echo -e "${CYAN}============================${NC}"
  echo -e "${CYAN}本机网络信息：${NC}"
  echo -e "${CYAN}IPv4 地址: ${ipv4_address}${NC}"
  echo -e "${CYAN}IPv6 地址: ${ipv6_address}${NC}"
  echo -e "${CYAN}============================${NC}"
  echo -e "${GREEN}1. IPv4 禁 Ping (当前状态: ${ipv4_status})${NC}"
  echo -e "${YELLOW}2. IPv6 禁 Ping (当前状态: ${ipv6_status})${NC}"
  echo -e "${RED}3. 查看当前 sysctl 配置${NC}"
  echo -e "${WHITE}0. 退出脚本${NC}"
  echo -e "${CYAN}============================${NC}"
}

# 切换 IPv4 禁 Ping 状态
toggle_ipv4_icmp_ignore() {
  if [ "$(get_public_ipv4)" == "无 IPv4" ]; then
    echo -e "${RED}错误：本机未配置 IPv4 地址，无法操作。${NC}"
    return 1
  fi

  local current_status=$(grep "^net.ipv4.icmp_echo_ignore_all=" "$CONFIG_FILE" 2>/dev/null | awk -F= '{print $2}')
  if [ "$current_status" == "1" ]; then
    echo -e "${GREEN}正在恢复 IPv4 Ping...${NC}"
    sed -i 's/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo -e "${GREEN}正在设置 IPv4 禁 Ping...${NC}"
    if grep -q "net.ipv4.icmp_echo_ignore_all" "$CONFIG_FILE"; then
      sed -i 's/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=1/' "$CONFIG_FILE"
    else
      echo "net.ipv4.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
    fi
  fi

  echo -e "${GREEN}使配置生效...${NC}"
  if ! sysctl -p; then
    echo -e "${RED}错误：无法应用配置。${NC}"
    return 1
  fi
  echo -e "${GREEN}IPv4 禁 Ping 状态已切换。${NC}"
}

# 切换 IPv6 禁 Ping 状态
toggle_ipv6_icmp_ignore() {
  if [ "$(get_public_ipv6)" == "无 IPv6" ]; then
    echo -e "${RED}错误：本机未配置 IPv6 地址，无法操作。${NC}"
    return 1
  fi

  local current_status=$(grep "^net.ipv6.icmp_echo_ignore_all=" "$CONFIG_FILE" 2>/dev/null | awk -F= '{print $2}')
  if [ "$current_status" == "1" ]; then
    echo -e "${YELLOW}正在恢复 IPv6 Ping...${NC}"
    sed -i 's/^net.ipv6.icmp_echo_ignore_all=.*/net.ipv6.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo -e "${YELLOW}正在设置 IPv6 禁 Ping...${NC}"
    if grep -q "net.ipv6.icmp_echo_ignore_all" "$CONFIG_FILE"; then
      sed -i 's/^net.ipv6.icmp_echo_ignore_all=.*/net.ipv6.icmp_echo_ignore_all=1/' "$CONFIG_FILE"
    else
      echo "net.ipv6.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
    fi
  fi

  echo -e "${YELLOW}使配置生效...${NC}"
  if ! sysctl -p; then
    echo -e "${RED}错误：无法应用配置。${NC}"
    return 1
  fi
  echo -e "${YELLOW}IPv6 禁 Ping 状态已切换。${NC}"
}

# 查看当前 sysctl 配置
view_sysctl_config() {
  echo -e "${RED}当前的 sysctl 配置文件内容如下：${NC}"
  echo -e "${RED}----------------------------------${NC}"
  cat "$CONFIG_FILE"
  echo -e "${RED}----------------------------------${NC}"
}

# 主循环
while true; do
  show_menu
  read -p "请输入选项: " choice
  case $choice in
    1)
      toggle_ipv4_icmp_ignore
      ;;
    2)
      toggle_ipv6_icmp_ignore
      ;;
    3)
      view_sysctl_config
      ;;
    0)
      echo -e "${WHITE}退出脚本...${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}错误：无效选项，请按任意键返回菜单...${NC}"
      read -n 1 -s  # 等待用户按任意键
      continue
      ;;
  esac

  # 提示按任意键返回菜单
  read -n 1 -s -r -p "$(echo -e ${CYAN}操作完成，按任意键返回菜单...${NC})"
  echo
done
