#!/bin/bash

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 用户运行此脚本！"
  exit 1
fi

# 获取主机名
hostname=$(hostname)

# 定义一个暂停函数
pause() {
  read -n 1 -s -r -p "按任意键继续..."
  echo ""
}

# 修改 SSH 端口的函数
modify_ssh_port() {
  clear
  echo "======================="
  echo "   修改 SSH 端口工具"
  echo "======================="
  echo "当前主机名: $hostname"
  current_port=$(grep -i "^Port " /etc/ssh/sshd_config | awk '{print $2}')
  current_port=${current_port:-22} # 默认端口为 22
  echo "当前 SSH 端口为: $current_port"
  echo ""

  # 输入新的端口号
  read -p "请输入新的 SSH 端口号（1-65535）： " new_port

  # 检查端口号合法性
  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
    echo "错误：输入的端口号无效，请输入 1-65535 范围内的数字！"
    pause
    exit 1
  fi

  # 修改 sshd_config 文件
  config_file="/etc/ssh/sshd_config"
  if grep -q "^Port " "$config_file"; then
    sed -i "s/^Port .*/Port $new_port/" "$config_file"
  else
    echo "Port $new_port" >> "$config_file"
  fi
  echo "SSH 端口已修改为: $new_port"

  # 重启 SSH 服务
  if systemctl restart ssh; then
    echo "SSH 服务已重启成功！"
    echo "======================="
    echo "新的 SSH 配置生效："
    echo "  主机名  : $hostname"
    echo "  新端口  : $new_port"
    echo "======================="
    echo "提示：请确保已在防火墙中开放新端口 $new_port！"
    echo "脚本即将退出，请测试新的端口连接。"
    exit 0
  else
    echo "错误：SSH 服务重启失败，请手动检查！"
    pause
    exit 1
  fi
}

# 启动脚本
modify_ssh_port
