#!/bin/bash

CONFIG_FILE="/etc/sysctl.conf"
BACKUP_FILE="/etc/sysctl.conf.backup"

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
  echo "3. 设置 IPv4/IPv6 禁 Ping"
  echo "4. 恢复原样"
  echo "0. 退出脚本"
  echo "============================"
}

# 设置 IPv4 禁 Ping
set_ipv4_icmp_ignore() {
  echo "正在备份当前配置..."
  if ! cp "$CONFIG_FILE" "$BACKUP_FILE"; then
    echo "错误：无法备份配置文件。"
    return 1
  fi

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
  echo "正在备份当前配置..."
  if ! cp "$CONFIG_FILE" "$BACKUP_FILE"; then
    echo "错误：无法备份配置文件。"
    return 1
  fi

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

# 设置 IPv4/IPv6 禁 Ping
set_all_icmp_ignore() {
  echo "正在备份当前配置..."
  if ! cp "$CONFIG_FILE" "$BACKUP_FILE"; then
    echo "错误：无法备份配置文件。"
    return 1
  fi

  echo "正在设置 IPv4 和 IPv6 禁 Ping..."
  if grep -q "net.ipv4.icmp_echo_ignore_all" "$CONFIG_FILE"; then
    sed -i 's/^net.ipv4.icmp_echo_ignore_all=.*/net.ipv4.icmp_echo_ignore_all=1/' "$CONFIG_FILE"
  else
    echo "net.ipv4.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  fi

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
  echo "IPv4 和 IPv6 禁 Ping 已设置完成。"
}

# 恢复原样
revert_icmp_config() {
  if [ -f "$BACKUP_FILE" ]; then
    echo "正在恢复原样..."
    if ! cp "$BACKUP_FILE" "$CONFIG_FILE"; then
      echo "错误：无法恢复配置文件。"
      return 1
    fi

    echo "使配置生效..."
    if ! sysctl -p; then
      echo "错误：无法应用配置。"
      return 1
    fi
    echo "配置已成功恢复原样。"
  else
    echo "未找到备份文件，无法恢复原样。"
  fi
}

# 主循环
while true; do
  show_menu
  read -p "请输入选项 (1/2/3/4/0): " choice
  case $choice in
    1)
      set_ipv4_icmp_ignore
      ;;
    2)
      set_ipv6_icmp_ignore
      ;;
    3)
      set_all_icmp_ignore
      ;;
    4)
      revert_icmp_config
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
  echo "按回车键继续..."
  read
done
