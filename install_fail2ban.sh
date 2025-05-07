#!/bin/bash
#==================================================
# Fail2ban + UFW 安装与管理脚本（仅用于 SSH 爆破封禁）
# 适用于 Debian/Ubuntu 系统
#==================================================

#===== 颜色变量 =====
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

#===== 获取 SSH 端口函数 =====
function get_ssh_port() {
    local port
    if [ -f /etc/fail2ban/jail.local ]; then
        port=$(grep -E "^port\s*=" /etc/fail2ban/jail.local | awk -F'=' '{print $2}' | tr -d ' ')
    fi
    if [ -z "$port" ] && [ -f /etc/ssh/sshd_config ]; then
        port=$(grep -E "^Port\s+" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
    fi
    echo "${port:-22}"
}

#===== 显示主菜单 =====
function show_menu() {
    clear
    local install_status
    if dpkg -l | grep -qw fail2ban; then
        install_status="已安装"
    else
        install_status="未安装"
    fi

    echo -e "${BLUE}==============================${RESET}"
    echo -e "${GREEN}      Fail2ban 管理脚本       ${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -e "当前状态: ${YELLOW}${install_status}${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -e "${YELLOW}1. 安装 fail2ban + UFW${RESET}"
    echo -e "${YELLOW}2. 查看 fail2ban 状态${RESET}"
    echo -e "${YELLOW}3. 查看 SSH 封禁情况${RESET}"
    echo -e "${YELLOW}4. 查看配置文件${RESET}"
    echo -e "${YELLOW}5. 实时查看 fail2ban 日志${RESET}"
    echo -e "${YELLOW}6. 手动封禁/解封 IP${RESET}"
    echo -e "${YELLOW}7. 卸载 fail2ban + UFW 并清理日志${RESET}"
    echo -e "${YELLOW}0. 退出${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -n "请选择操作: "
}

#===== 查看原始状态 =====
function original_view_status() {
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}fail2ban 已启动${RESET}"
    else
        echo -e "${RED}fail2ban 未运行${RESET}"
    fi
    sudo fail2ban-client status 2>/dev/null
}

#===== 安装 fail2ban + UFW =====
function install_fail2ban() {
    echo -e "${GREEN}开始安装 fail2ban + UFW...${RESET}"
    sudo apt-get update && sudo apt-get upgrade -y

    echo -e "${BLUE}安装依赖：rsyslog 和 ufw...${RESET}"
    sudo apt-get install -y rsyslog ufw

    echo -e "${BLUE}检测系统环境...${RESET}"
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${GREEN}系统: $NAME $VERSION${RESET}"
    else
        echo -e "${RED}无法检测系统环境。${RESET}"
    fi

    # 检测 SSH 端口
    local ssh_port
    ssh_port=$(grep -E "^Port\s+" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
    if [ -z "$ssh_port" ]; then
        echo -e "${YELLOW}未检测到 SSH 端口，请手动输入。${RESET}"
        read -p "请输入 SSH 端口: " ssh_port
        read -p "确认 SSH 端口为 $ssh_port (y/n): " confirm
        if [[ "$confirm" != [Yy] ]]; then
            echo -e "${RED}SSH 端口未确认，退出安装。${RESET}"
            read -n1 -s -p "按任意键返回菜单..."
            return
        fi
    else
        echo -e "${GREEN}检测到 SSH 端口: $ssh_port${RESET}"
    fi

    # UFW 仅用于 Fail2ban 封禁：设置为默认允许所有流量
    echo -e "${BLUE}配置 UFW 默认策略为 allow all...${RESET}"
    sudo ufw default allow incoming
    sudo ufw default allow outgoing
    echo "y" | sudo ufw enable

    # 安装 Fail2ban
    echo -e "${BLUE}安装 fail2ban...${RESET}"
    sudo apt-get install -y fail2ban

    # 生成 jail.local
    echo -e "${BLUE}生成 /etc/fail2ban/jail.local 配置...${RESET}"
    sudo mkdir -p /etc/fail2ban
    [ -f /etc/fail2ban/jail.conf ] && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak

    sudo bash -c "cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 3600
findtime = 300
maxretry = 5
banaction = ufw

[sshd]
enabled = true
port    = $ssh_port
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF"

    echo -e "${GREEN}生成的配置文件：${RESET}"
    cat /etc/fail2ban/jail.local

    sudo systemctl restart fail2ban
    sudo systemctl enable fail2ban
    echo -e "${GREEN}fail2ban 已启动并设置为开机自启。${RESET}"

    # 日志清理定时任务
    echo -e "${BLUE}设置每 15 天清理一次日志...${RESET}"
    local cron_job="0 0 */15 * * root echo '' > /var/log/fail2ban.log"
    (sudo crontab -l 2>/dev/null | grep -v 'fail2ban.log'; echo "$cron_job") | sudo crontab -

    echo -e "${BLUE}当前状态：${RESET}"
    original_view_status

    read -n1 -s -p "安装完成，按任意键返回菜单..."
}

#===== 查看 fail2ban 状态 =====
function view_fail2ban_status() {
    echo -e "${GREEN}fail2ban 状态：${RESET}"
    sudo service fail2ban status
    read -n1 -s -p "按任意键返回菜单..."
}

#===== 查看 SSH 封禁情况 =====
function view_ssh_status() {
    local ssh_port
    ssh_port=$(get_ssh_port)
    echo -e "${GREEN}Fail2ban SSH 封禁：${RESET}"
    sudo fail2ban-client status sshd 2>/dev/null
    echo -e "${GREEN}UFW 规则中针对端口 $ssh_port 的 deny 条目：${RESET}"
    sudo ufw status numbered | grep "$ssh_port"
    read -n1 -s -p "按任意键返回菜单..."
}

#===== 查看配置文件 =====
function view_config() {
    echo -e "${GREEN}/etc/fail2ban/jail.local 内容：${RESET}"
    if [ -f /etc/fail2ban/jail.local ]; then
        cat /etc/fail2ban/jail.local
    else
        echo -e "${RED}文件不存在！${RESET}"
    fi
    read -n1 -s -p "按任意键返回菜单..."
}

#===== 实时查看日志 =====
function tail_log() {
    echo -e "${GREEN}实时查看 /var/log/fail2ban.log（Ctrl+C 退出）${RESET}"
    if [ -f /var/log/fail2ban.log ]; then
        sudo tail -n 50 -F /var/log/fail2ban.log
    else
        echo -e "${RED}日志文件不存在！${RESET}"
    fi
    echo
    read -n1 -s -p "按任意键返回菜单..."
}

#===== 手动封禁/解封 IP =====
function manual_ban() {
    local ssh_port ip_addr
    ssh_port=$(get_ssh_port)
    read -p "请输入目标 IP: " ip_addr
    echo -e "${YELLOW}1. 封禁   2. 解封${RESET}"
    read -p "请选择 (1/2): " action
    if [ "$action" == "1" ]; then
        echo -e "${BLUE}UFW 封禁 $ip_addr 端口 $ssh_port...${RESET}"
        sudo ufw deny from "$ip_addr" to any port "$ssh_port"
        echo -e "${GREEN}已封禁。${RESET}"
    elif [ "$action" == "2" ]; then
        echo -e "${BLUE}UFW 解封 $ip_addr...${RESET}"
        sudo ufw delete deny from "$ip_addr" to any port "$ssh_port"
        echo -e "${GREEN}已解封。${RESET}"
    else
        echo -e "${RED}无效选择！${RESET}"
    fi
    read -n1 -s -p "按任意键返回菜单..."
}

#===== 卸载并清理 =====
function uninstall_fail2ban() {
    echo -e "${GREEN}开始卸载 fail2ban + UFW 并清理残留...${RESET}"

    # 停止并卸载 fail2ban
    sudo systemctl stop fail2ban
    sudo apt-get remove --purge -y fail2ban rsyslog

    # 停止并卸载 ufw
    sudo ufw disable
    sudo apt-get remove --purge -y ufw

    # 清理配置文件和日志
    sudo rm -rf /etc/fail2ban /etc/ufw
    sudo rm -f /var/log/fail2ban.log /var/log/ufw.log

    # 清理定时任务
    sudo crontab -l 2>/dev/null | grep -v 'fail2ban.log' | sudo crontab -

    echo -e "${GREEN}卸载并清理完成。${RESET}"
    read -n1 -s -p "卸载完成，按任意键返回菜单..."
}

#===== 主循环 =====
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_fail2ban ;;
        2) view_fail2ban_status ;;
        3) view_ssh_status ;;
        4) view_config ;;
        5) tail_log ;;
        6) manual_ban ;;
        7) uninstall_fail2ban ;;
        0)
            echo -e "${GREEN}退出。${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重试。${RESET}"
            sleep 1
            ;;
    esac
done
