#!/bin/bash

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[31m错误：请使用 root 用户运行此脚本！\033[0m"
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
  while true; do
    clear
    echo -e "\033[34m=======================\033[0m"
    echo -e "\033[34m   修改 SSH 端口工具   \033[0m"
    echo -e "\033[34m=======================\033[0m"
    echo -e "当前主机名: \033[32m$hostname\033[0m"
    current_port=$(grep -i "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    current_port=${current_port:-22} # 默认端口为 22
    echo -e "当前 SSH 端口为: \033[33m$current_port\033[0m"
    echo ""
    echo -e "\033[36m请输入新的 SSH 端口号（1-65535），或输入 0 退出菜单：\033[0m"
    read -p "请输入: " new_port

    # 检查是否退出菜单
    if [[ "$new_port" == "0" ]]; then
      echo -e "\033[33m退出菜单。\033[0m"
      pause
      return
    fi

    # 检查端口号合法性
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
      echo -e "\033[31m错误：端口号无效，请输入 1-65535 范围内的数字！\033[0m"
      pause
      continue
    fi

    # 修改 sshd_config 文件
    config_file="/etc/ssh/sshd_config"
    if grep -q "^Port " "$config_file"; then
      sed -i "s/^Port .*/Port $new_port/" "$config_file"
    else
      echo "Port $new_port" >> "$config_file"
    fi
    echo -e "\033[32mSSH 端口已修改为: $new_port\033[0m"

    # 重启 SSH 服务
    if systemctl restart ssh; then
      echo -e "\033[32mSSH 服务已重启成功！\033[0m"
      echo -e "\033[34m=======================\033[0m"
      echo -e "\033[34m新的 SSH 配置生效：\033[0m"
      echo -e "  主机名  : \033[32m$hostname\033[0m"
      echo -e "  新端口  : \033[32m$new_port\033[0m"
      echo -e "\033[34m=======================\033[0m"
      echo -e "\033[33m提示：请确保已在防火墙中开放新端口 $new_port！\033[0m"
      echo -e "\033[33m脚本即将退出，请测试新的端口连接。\033[0m"
      exit 0
    else
      echo -e "\033[31m错误：SSH 服务重启失败，请手动检查！\033[0m"
      pause
      return
    fi
  done
}

# 主菜单函数
main_menu() {
  while true; do
    clear
    echo -e "\033[34m=======================\033[0m"
    echo -e "\033[34m   SSH 端口管理工具    \033[0m"
    echo -e "\033[34m=======================\033[0m"
    echo -e "当前主机名: \033[32m$hostname\033[0m"
    current_port=$(grep -i "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    current_port=${current_port:-22} # 默认端口为 22
    echo -e "当前 SSH 端口为: \033[33m$current_port\033[0m"
    echo ""
    echo -e "\033[36m请选择一个选项：\033[0m"
    echo -e "  1) 修改 SSH 端口"
    echo -e "  0) 退出脚本"
    echo ""
    read -p "请输入选项数字（0-1）： " choice

    case $choice in
      1)
        modify_ssh_port
        ;;
      0)
        echo -e "\033[32m退出脚本。\033[0m"
        exit 0
        ;;
      *)
        echo -e "\033[31m错误：无效选项，请输入 0 或 1！\033[0m"
        pause
        ;;
    esac
  done
}

# 启动主菜单
main_menu
