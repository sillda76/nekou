#!/bin/bash
#==================================================
# Fail2ban 安装与管理脚本
# 适用于 Debian/Ubuntu 系统
# 功能：
#  1. 安装 fail2ban
#  2. 查看 fail2ban 运行状态
#  3. 查看 SSH 服务的封禁情况
#  4. 查看 fail2ban 配置文件
#  5. 实时查看 fail2ban 日志
#  6. 手动封禁/解封 IP 地址
#  7. 卸载 fail2ban
#==================================================

#===== 颜色变量 =====
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"  # 无颜色

#===== 在主菜单显示当前 fail2ban 安装状态 =====
function show_menu() {
    local install_status
    if dpkg -l | grep -qw fail2ban; then
        install_status="已安装"
    else
        install_status="未安装"
    fi

    echo -e "${BLUE}==============================${NC}"
    echo -e "${GREEN}      Fail2ban 管理脚本       ${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo -e "当前状态: ${YELLOW}${install_status}${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo -e "${YELLOW}1. 安装 fail2ban${NC}"
    echo -e "${YELLOW}2. 查看 fail2ban 状态${NC}"
    echo -e "${YELLOW}3. 查看 SSH 服务封禁情况${NC}"
    echo -e "${YELLOW}4. 查看配置文件${NC}"
    echo -e "${YELLOW}5. 实时查看 fail2ban 日志${NC}"
    echo -e "${YELLOW}6. 手动封禁/解封 IP 地址${NC}"
    echo -e "${YELLOW}7. 卸载 fail2ban 并清理日志${NC}"
    echo -e "${YELLOW}0. 退出${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo -n "请选择操作: "
}

#===== 显示 fail2ban 运行状态（使用绿色/红色提示）=====
function view_status() {
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}fail2ban 当前状态：已启动${NC}"
    else
        echo -e "${RED}fail2ban 当前状态：未运行${NC}"
    fi
    # 也可显示详细信息
    sudo fail2ban-client status 2>/dev/null
}

#===== 选项1：安装 fail2ban =====
function install_fail2ban() {
    echo -e "${GREEN}开始安装 fail2ban...${NC}"
    
    # 1. 更新系统软件包
    echo -e "${BLUE}更新系统软件包...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y

    # 2. 检查并安装所需依赖：rsyslog 和 iptables
    echo -e "${BLUE}检查并安装依赖：rsyslog 和 iptables...${NC}"
    sudo apt-get install -y rsyslog iptables

    # 3. 检测当前系统环境
    echo -e "${BLUE}检测当前系统环境...${NC}"
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${GREEN}系统: $NAME $VERSION${NC}"
    else
        echo -e "${RED}无法检测系统环境，可能不是 Debian/Ubuntu 系统。${NC}"
    fi

    # 4. 检测 SSH 端口
    ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n 1)
    if [ -z "$ssh_port" ]; then
        echo -e "${YELLOW}未能自动检测到 SSH 端口，请手动输入。${NC}"
        read -p "请输入 SSH 端口: " ssh_port
        read -p "确认 SSH 端口为 $ssh_port (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${RED}SSH 端口未确认，退出安装。${NC}"
            return
        fi
    else
        echo -e "${GREEN}检测到 SSH 端口: $ssh_port${NC}"
    fi

    # 5. 安装 fail2ban
    echo -e "${BLUE}安装 fail2ban...${NC}"
    sudo apt-get install -y fail2ban

    # 6. 生成 fail2ban 配置文件
    echo -e "${BLUE}生成 fail2ban 配置文件...${NC}"
    sudo mkdir -p /etc/fail2ban
    # 备份原始配置（若存在）
    [ -f /etc/fail2ban/jail.conf ] && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak

    # 生成 /etc/fail2ban/jail.local
    sudo bash -c "cat > /etc/fail2ban/jail.local" <<EOF
[DEFAULT]
# 白名单：环回地址
ignoreip = 127.0.0.1/8 ::1
# 封禁时间（秒）
bantime  = 3600
# 检测范围（秒）
findtime = 300
# 失败次数
maxretry = 5
# 释放封禁的时间（注释，仅供参考）
# unban_after = 7200

[sshd]
enabled = true
port    = $ssh_port
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF

    # 显示生成的配置文件内容
    echo -e "${GREEN}生成的 fail2ban 配置文件内容如下:${NC}"
    cat /etc/fail2ban/jail.local

    # 7. 启动 fail2ban 并设置开机自启
    sudo systemctl start fail2ban
    sudo systemctl enable fail2ban
    echo -e "${GREEN}fail2ban 已启动并设置为开机自启。${NC}"

    # 8. 设置每十五天清理一次 fail2ban 日志的定时任务
    echo -e "${BLUE}设置定时任务，每十五天清理一次 fail2ban 日志...${NC}"
    cron_job="0 0 */15 * * root echo '' > /var/log/fail2ban.log"
    (sudo crontab -l 2>/dev/null | grep -v 'fail2ban.log'; echo "$cron_job") | sudo crontab -

    # 9. 自动显示运行状态
    echo -e "${BLUE}当前 fail2ban 运行状态:${NC}"
    view_status

    # 10. 提示安装完成
    echo -e "${GREEN}fail2ban 安装完成。${NC}"
}

#===== 选项2：查看 fail2ban 状态 =====
function view_fail2ban_status() {
    echo -e "${GREEN}fail2ban 当前状态:${NC}"
    view_status
}

#===== 选项3：查看 SSH 服务封禁情况 =====
function view_ssh_status() {
    echo -e "${GREEN}SSH 服务封禁情况：${NC}"
    sudo fail2ban-client status sshd 2>/dev/null
}

#===== 选项4：查看配置文件 =====
function view_config() {
    echo -e "${GREEN}fail2ban 配置文件 (/etc/fail2ban/jail.local) 内容：${NC}"
    if [ -f /etc/fail2ban/jail.local ]; then
        cat /etc/fail2ban/jail.local
    else
        echo -e "${RED}/etc/fail2ban/jail.local 文件不存在！${NC}"
    fi
}

#===== 选项5：实时查看 fail2ban 日志 =====
function tail_log() {
    echo -e "${GREEN}实时查看 fail2ban 日志（按 q 键退出）:${NC}"
    if [ -f /var/log/fail2ban.log ]; then
        sudo less +F /var/log/fail2ban.log
    else
        echo -e "${RED}未找到 /var/log/fail2ban.log 日志文件！${NC}"
    fi
}

#===== 选项6：手动封禁/解封 IP 地址 =====
function manual_ban() {
    echo -e "${GREEN}手动封禁/解封 IP 地址${NC}"
    read -p "请输入目标 IP 地址: " ip_addr
    echo -e "${YELLOW}请选择操作：1. 封禁   2. 解封${NC}"
    read -p "请选择操作 (1/2): " action
    if [ "$action" == "1" ]; then
        echo -e "${BLUE}正在封禁 IP: $ip_addr ...${NC}"
        sudo fail2ban-client set sshd banip "$ip_addr" 2>/dev/null
        echo -e "${GREEN}IP $ip_addr 已被封禁。${NC}"
    elif [ "$action" == "2" ]; then
        echo -e "${BLUE}正在解封 IP: $ip_addr ...${NC}"
        sudo fail2ban-client set sshd unbanip "$ip_addr" 2>/dev/null
        echo -e "${GREEN}IP $ip_addr 已被解封。${NC}"
    else
        echo -e "${RED}无效操作，请选择 1 或 2。${NC}"
    fi
}

#===== 选项7：卸载 fail2ban 并清理日志 =====
function uninstall_fail2ban() {
    echo -e "${GREEN}正在卸载 fail2ban 并清理相关配置及日志...${NC}"
    sudo systemctl stop fail2ban
    sudo apt-get remove --purge -y fail2ban
    sudo rm -rf /etc/fail2ban
    sudo rm -f /var/log/fail2ban.log
    # 清理定时任务中关于 fail2ban 日志的行
    sudo crontab -l 2>/dev/null | grep -v 'fail2ban.log' | sudo crontab -
    echo -e "${GREEN}fail2ban 已卸载，相关日志及配置文件已清理。${NC}"
}

#===== 主循环：显示菜单并处理用户输入 =====
while true; do
    show_menu
    read choice
    case $choice in
        1)
            install_fail2ban
            ;;
        2)
            view_fail2ban_status
            ;;
        3)
            view_ssh_status
            ;;
        4)
            view_config
            ;;
        5)
            tail_log
            ;;
        6)
            manual_ban
            ;;
        7)
            uninstall_fail2ban
            ;;
        0)
            echo -e "${GREEN}退出脚本。${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新选择。${NC}"
            ;;
    esac
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1 -s
done
