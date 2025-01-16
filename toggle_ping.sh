#!/bin/bash

CONFIG_FILE="/etc/sysctl.conf"

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本"
  exit 1
fi

# 获取本机 IP 地址
get_ip_address() {
  echo "========== 本机 IP 地址 =========="
  ipv4_address=$(curl -s https://ifconfig.co/ip)
  ipv6_address=$(curl -s https://ifconfig.co)

  if [ -n "$ipv4_address" ]; then
    echo "IPv4: $ipv4_address"
  fi

  if [ -n "$ipv6_address" ]; then
    echo "IPv6: $ipv6_address"
  fi

  if [ -z "$ipv4_address" ] && [ -z "$ipv6_address" ]; then
    echo "未检测到有效的 IPv4 或 IPv6 地址。"
  fi
  echo "================================"
}

# 显示菜单
show_menu() {
  get_ip_address
  echo "============================"
  echo "请选择要执行的操作："
  echo "1. IPv4 禁 Ping 状态 (当前状态: $(get_ipv4_ping_status))"
  echo "2. IPv6 禁 Ping 状态 (当前状态: $(get_ipv6_ping_status))"
  echo "3. 查看当前 sysctl 配置"
  echo "0. 退出脚本"
  echo "============================"
}

# 获取 IPv4 Ping 状态
get_ipv4_ping_status() {
  if ! ip -4 route &> /dev/null; then
    echo "无 IPv4"
  elif grep -q "^net.ipv4.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo "已启用"
  else
    echo "未启用"
  fi
}

# 获取 IPv6 Ping 状态
get_ipv6_ping_status() {
  if ! ip -6 route &> /dev/null; then
    echo "无 IPv6"
  elif grep -q "^net.ipv6.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo "已启用"
  else
    echo "未启用"
  fi
}

# 设置/恢复 IPv4 Ping
toggle_ipv4_ping() {
  if ! ip -4 route &> /dev/null; then
    echo "错误：未检测到 IPv4 网络。"
    return 1
  fi

  if grep -q "^net.ipv4.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo "正在恢复 IPv4 Ping..."
    sed -i 's/^net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo "正在设置 IPv4 禁 Ping..."
    sed -i '/^net.ipv4.icmp_echo_ignore_all/d' "$CONFIG_FILE"
    echo "net.ipv4.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

  echo "使配置生效..."
  if ! sysctl -p; then
    echo "错误：无法应用配置。"
    return 1
  fi
  echo "IPv4 Ping 状态已更新：$(get_ipv4_ping_status)"
}

# 设置/恢复 IPv6 Ping
toggle_ipv6_ping() {
  if ! ip -6 route &> /dev/null; then
    echo "错误：未检测到 IPv6 网络。"
    return 1
  fi

  if grep -q "^net.ipv6.icmp_echo_ignore_all=1" "$CONFIG_FILE"; then
    echo "正在恢复 IPv6 Ping..."
    sed -i 's/^net.ipv6.icmp_echo_ignore_all=1/net.ipv6.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo "正在设置 IPv6 禁 Ping..."
    sed -i '/^net.ipv6.icmp_echo_ignore_all/d' "$CONFIG_FILE"
    echo "net.ipv6.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

  echo "使配置生效..."
  if ! sysctl -p; then
    echo "错误：无法应用配置。"
    return 1
  fi
  echo "IPv6 Ping 状态已更新：$(get_ipv6_ping_status)"
}

# 查看当前 sysctl 配置
view_sysctl_config() {
  echo "当前的 sysctl 配置文件内容如下："
  echo "----------------------------------"
  cat "$CONFIG_FILE"
  echo "----------------------------------"
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
      echo "退出脚本..."
      exit 0
      ;;
    *)
      echo "错误：无效选项，请按任意键返回菜单..."
      read -n 1 -s  # 等待用户按任意键
      continue
      ;;
  esac

  # 提示按任意键返回菜单
  read -n 1 -s -r -p "操作完成，按任意键返回菜单..."
  echo
done
