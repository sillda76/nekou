#!/bin/bash

CONFIG_FILE="/etc/sysctl.conf"

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本"
  exit 1
fi

# 显示菜单
show_menu() {
  echo "============================"
  echo "请选择要执行的操作："
  echo "1. 设置 IPv4 禁 Ping"
  echo "2. 设置 IPv6 禁 Ping"
  echo "3. 恢复 IPv4 Ping"
  echo "4. 恢复 IPv6 Ping"
  echo "0. 退出脚本"
  echo "============================"
}

# 设置 IPv4 禁 Ping
set_ipv4_icmp_ignore() {
  echo "正在设置 IPv4 禁 Ping..."
  if grep -q "net.ipv4.icmp_echo_ignore_all" "$CONFIG_FILE"; then
    sed -i 's/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=1/' "$CONFIG_FILE"
  else
    echo "net.ipv4.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

  echo "使配置生效..."
  if ! sysctl -p; then
    echo "错误：无法应用配置。"
    return 1
  fi
  echo "IPv4 禁 Ping 已设置完成。"
}

# 设置 IPv6 禁 Ping
set_ipv6_icmp_ignore() {
  echo "正在设置 IPv6 禁 Ping..."
  if grep -q "net.ipv6.icmp_echo_ignore_all" "$CONFIG_FILE"; then
    sed -i 's/^net.ipv6.icmp_echo_ignore_all=.*/net.ipv6.icmp_echo_ignore_all=1/' "$CONFIG_FILE"
  else
    echo "net.ipv6.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

  echo "使配置生效..."
  if ! sysctl -p; then
    echo "错误：无法应用配置。"
    return 1
  fi
  echo "IPv6 禁 Ping 已设置完成。"
}

# 恢复 IPv4 Ping
restore_ipv4_ping() {
  echo "正在恢复 IPv4 Ping..."
  if grep -q "net.ipv4.icmp_echo_ignore_all" "$CONFIG_FILE"; then
    sed -i 's/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo "net.ipv4.icmp_echo_ignore_all=0" >> "$CONFIG_FILE"
  fi

  echo "使配置生效..."
  if ! sysctl -p; then
    echo "错误：无法应用配置。"
    return 1
  fi
  echo "IPv4 Ping 已恢复。"
}

# 恢复 IPv6 Ping
restore_ipv6_ping() {
  echo "正在恢复 IPv6 Ping..."
  if grep -q "net.ipv6.icmp_echo_ignore_all" "$CONFIG_FILE"; then
    sed -i 's/^net.ipv6.icmp_echo_ignore_all=.*/net.ipv6.icmp_echo_ignore_all=0/' "$CONFIG_FILE"
  else
    echo "net.ipv6.icmp_echo_ignore_all=0" >> "$CONFIG_FILE"
  fi

  echo "使配置生效..."
  if ! sysctl -p; then
    echo "错误：无法应用配置。"
    return 1
  fi
  echo "IPv6 Ping 已恢复。"
}

# 主循环
while true; do
  show_menu
  read -p "请输入选项: " choice
  case $choice in
    1)
      set_ipv4_icmp_ignore
      ;;
    2)
      set_ipv6_icmp_ignore
      ;;
    3)
      restore_ipv4_ping
      ;;
    4)
      restore_ipv6_ping
      ;;
    0)
      echo "退出脚本..."
      exit 0
      ;;
    *)
      echo "错误：无效选项，请按任意键返回菜单..."
      read -n 1 -s  # 等待用户按任意键
      ;;
  esac
done
