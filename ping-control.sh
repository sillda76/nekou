#!/bin/bash

CONFIG_FILE="/etc/sysctl.conf"
IP6TABLES_RULES_FILE="/etc/ip6tables.rules"

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m' # 亮绿色
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m' # 青色
PURPLE='\033[0;35m' # 紫色
NC='\033[0m' # 恢复默认颜色

# 检查是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请以 root 用户运行此脚本${NC}"
  exit 1
fi

# 检查依赖工具
check_dependencies() {
  for cmd in curl ip6tables; do
    if ! command -v "$cmd" &> /dev/null; then
      echo -e "${RED}依赖工具 $cmd 未安装，请先安装后再运行此脚本。${NC}"
      exit 1
    fi
  done
}

# 获取本机 IP 地址
get_ip_address() {
  ipv4_address=$(curl -4 -s https://icanhazip.com || echo "")
  if ! [[ "$ipv4_address" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    ipv4_address=""
  fi

  ipv6_address=$(curl -6 -s https://icanhazip.com || echo "")
  if ! [[ "$ipv6_address" =~ ^[0-9a-fA-F:]+$ ]]; then
    ipv6_address=""
  fi
}

# 获取 IPv4 Ping 状态
get_ipv4_ping_status() {
  if grep -q "^net.ipv4.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo -e "${RED}已启用${NC}"
  else
    echo -e "${LIGHT_GREEN}未启用${NC}"
  fi
}

# 获取 IPv6 Ping 状态
get_ipv6_ping_status() {
  if ip6tables -L INPUT -v -n | grep -q "icmpv6.*echo-request.*DROP"; then
    echo -e "${RED}已启用${NC}"
  else
    echo -e "${LIGHT_GREEN}未启用${NC}"
  fi
}

# 设置/恢复 IPv4 Ping
toggle_ipv4_ping() {
  if grep -q "^net.ipv4.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo -e "${GREEN}正在恢复 IPv4 Ping...${NC}"
    sed -i 's/^net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo -e "${RED}正在设置 IPv4 禁 Ping...${NC}"
    sed -i '/^net.ipv4.icmp_echo_ignore_all/d' "$CONFIG_FILE"
    echo "net.ipv4.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

  echo -e "${BLUE}使配置生效...${NC}"
  if sysctl -p; then
    echo -e "IPv4 Ping 状态已更新：$(get_ipv4_ping_status)"
  else
    echo -e "${RED}错误：无法应用配置。${NC}"
  fi
}

# 设置/恢复 IPv6 Ping
toggle_ipv6_ping() {
  if ip6tables -L INPUT -v -n | grep -q "icmpv6.*echo-request.*DROP"; then
    echo -e "${GREEN}正在恢复 IPv6 Ping...${NC}"
    ip6tables -D INPUT -p icmpv6 --icmpv6-type echo-request -j DROP
  else
    echo -e "${RED}正在设置 IPv6 禁 Ping...${NC}"
    ip6tables -A INPUT -p icmpv6 --icmpv6-type echo-request -j DROP
  fi

  # 保存规则
  ip6tables-save > "$IP6TABLES_RULES_FILE"
  echo -e "${BLUE}IPv6 Ping 状态已更新：$(get_ipv6_ping_status)${NC}"
}

# 查看 IPv4 禁 Ping 配置
view_ipv4_ping_config() {
  echo -e "${BLUE}当前的 IPv4 禁 Ping 配置如下：${NC}"
  grep "^net.ipv4.icmp_echo_ignore_all" "$CONFIG_FILE" || echo -e "${YELLOW}未找到相关配置。${NC}"
}

# 查看 IPv6 禁 Ping 配置
view_ipv6_ping_config() {
  echo -e "${BLUE}当前的 IPv6 禁 Ping 配置如下：${NC}"
  ip6tables -L INPUT -v -n | grep "icmpv6.*echo-request.*DROP" || echo -e "${YELLOW}未找到相关配置。${NC}"
}

# 显示菜单
show_menu() {
  clear
  get_ip_address

  echo -e "${BLUE}========== 本机 IP 地址 ==========${NC}"
  [ -n "$ipv4_address" ] && echo -e "${GREEN}IPv4: $ipv4_address${NC}"
  [ -n "$ipv6_address" ] && echo -e "${CYAN}IPv6: $ipv6_address${NC}"
  echo -e "${BLUE}==================================${NC}"

  echo -e "${PURPLE}请选择要执行的操作：${NC}"
  [ -n "$ipv4_address" ] && echo -e "${RED}1. IPv4 禁 Ping 状态 (当前状态: $(get_ipv4_ping_status))${NC}"
  [ -n "$ipv6_address" ] && echo -e "${GREEN}2. IPv6 禁 Ping 状态 (当前状态: $(get_ipv6_ping_status))${NC}"
  [ -n "$ipv4_address" ] && echo -e "${CYAN}3. 查看 IPv4 禁 Ping 配置${NC}"
  [ -n "$ipv6_address" ] && echo -e "${ORANGE}4. 查看 IPv6 禁 Ping 配置${NC}"
  echo -e "${BLUE}0. 退出脚本${NC}"
}

# 主循环
main() {
  check_dependencies
  while true; do
    show_menu
    read -p "请输入选项: " choice
    case $choice in
      1)
        [ -n "$ipv4_address" ] && toggle_ipv4_ping || echo -e "${RED}错误：无效选项。${NC}"
        ;;
      2)
        [ -n "$ipv6_address" ] && toggle_ipv6_ping || echo -e "${RED}错误：无效选项。${NC}"
        ;;
      3)
        [ -n "$ipv4_address" ] && view_ipv4_ping_config || echo -e "${RED}错误：无效选项。${NC}"
        ;;
      4)
        [ -n "$ipv6_address" ] && view_ipv6_ping_config || echo -e "${RED}错误：无效选项。${NC}"
        ;;
      0)
        echo -e "${ORANGE}退出脚本...${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}错误：无效选项，请重新输入。${NC}"
        ;;
    esac
    read -n 1 -s -r -p "$(echo -e ${BLUE}按任意键返回菜单...${NC})"
  done
}

# 执行主函数
main
