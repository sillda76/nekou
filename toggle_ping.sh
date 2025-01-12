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
  echo "1. 设置禁 Ping"
  echo "2. 恢复原样"
  echo "0. 返回菜单"
  echo "============================"
}

# 设置禁 Ping
set_icmp_ignore() {
  echo "正在备份当前配置..."
  cp "$CONFIG_FILE" "$BACKUP_FILE"

  echo "正在设置禁 Ping..."
  echo "net.ipv4.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"
  echo "net.ipv6.icmp_echo_ignore_all=1" >> "$CONFIG_FILE"

  echo "使配置生效..."
  sysctl -p
  echo "禁 Ping 已设置完成。"
}

# 恢复原样
revert_icmp_config() {
  if [ -f "$BACKUP_FILE" ]; then
    echo "正在恢复原样..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"

    echo "使配置生效..."
    sysctl -p
    echo "配置已成功恢复原样。"
  else
    echo "未找到备份文件，无法恢复原样。"
  fi
}

# 主循环
while true; do
  show_menu
  read -p "请输入选项 (1/2/0): " choice
  case $choice in
    1)
      set_icmp_ignore
      ;;
    2)
      revert_icmp_config
      ;;
    0)
      echo "返回菜单..."
      o  # 运行指定的命令
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
