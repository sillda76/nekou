#!/bin/bash
#==================================================
# Fail2ban + iptables 安装与管理脚本（仅用于 SSH 爆破封禁）
# 适用于 Debian/Ubuntu 系统
#==================================================

#===== 颜色变量 =====
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
RESET="\e[0m"

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
    echo -e "${YELLOW}1. 安装 fail2ban + iptables${RESET}"
    echo -e "${YELLOW}2. 查看 fail2ban 状态${RESET}"
    echo -e "${YELLOW}3. 查看 SSH 封禁情况${RESET}"
    echo -e "${YELLOW}4. 查看配置文件${RESET}"
    echo -e "${YELLOW}5. 实时查看 fail2ban 日志${RESET}"
    echo -e "${YELLOW}6. 手动封禁/解封 IP${RESET}"
    echo -e "${YELLOW}7. 卸载 fail2ban + iptables 并清理日志${RESET}"
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

#===== 安装 fail2ban + iptables =====
function install_fail2ban() {
    echo -e "${GREEN}开始安装 fail2ban + iptables...${RESET}"
    sudo apt-get update && sudo apt-get upgrade -y

    echo -e "${BLUE}安装依赖：rsyslog、iptables-persistent 和 fail2ban...${RESET}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y rsyslog iptables-persistent fail2ban

    # 获取 SSH 端口
    local ssh_port
    ssh_port=$(get_ssh_port)
    echo -e "${GREEN}检测到 SSH 端口: $ssh_port${RESET}"

    # 生成或备份并写入 jail.local
    echo -e "${BLUE}生成 /etc/fail2ban/jail.local 配置...${RESET}"
    sudo mkdir -p /etc/fail2ban
    [ -f /etc/fail2ban/jail.conf ] && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak
    sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 3600
findtime = 300
maxretry = 5
banaction = iptables

[sshd]
enabled = true
port    = $ssh_port
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF

    # 重启并启用服务
    sudo systemctl restart fail2ban
    sudo systemctl enable fail2ban
    echo -e "${GREEN}fail2ban 已启动并设置为开机自启。${RESET}"

    echo -e "${BLUE}安装完成。按任意键返回菜单...${RESET}"
    read -n1 -s
}

#===== 查看 fail2ban 状态 =====
function view_fail2ban_status() {
    echo -e "${GREEN}fail2ban 状态：${RESET}"
    sudo service fail2ban status
    echo -e "${BLUE}按任意键返回菜单...${RESET}"
    read -n1 -s
}

#===== 查看 SSH 封禁情况 =====
function view_ssh_status() {
    local ssh_port f2b_ips
    ssh_port=$(get_ssh_port)

    echo -e "${GREEN}当前 SSH 端口: ${YELLOW}$ssh_port${RESET}"
    echo -e "${BLUE}==============================${RESET}"

    # 系统时间
    timezone=$(cat /etc/timezone 2>/dev/null)
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "系统时间: ${YELLOW}${timezone} ${current_time}${RESET}"

    # Fail2ban 封禁列表
    echo -e "${GREEN}当前活跃封禁 IP (Fail2ban):${RESET}"
    f2b_ips=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Banned IP list:" | sed 's/.*://')
    if [[ -z "$f2b_ips" || "$f2b_ips" == "None" ]]; then
        echo -e "${YELLOW}当前没有活跃的 Fail2ban 封禁 IP${RESET}"
    else
        IFS=', ' read -ra ips <<< "$f2b_ips"
        local count=1
        for ip in "${ips[@]}"; do
            ban_time=$(sudo zgrep -h "Ban $ip" /var/log/fail2ban.log* 2>/dev/null | awk '{print $1" "$2}' | tail -n 1)
            printf "${YELLOW}%2d) ${RED}%-15s ${BLUE}封禁时间: ${GREEN}%s${RESET}\n" \
                   "$count" "$ip" "${ban_time:-时间未知}"
            ((count++))
        done
    fi

    echo -e "${BLUE}==============================${RESET}"
    # iptables 手动封禁列表
    echo -e "${GREEN}当前活跃封禁 IP (iptables -dport $ssh_port DROP):${RESET}"
    sudo iptables -L INPUT -n --line-numbers | grep "DROP" | grep "dpt:$ssh_port" | while read -r line; do
        num=$(echo $line | awk '{print $1}')
        src=$(echo $line | awk '{print $4}')
        echo -e "${YELLOW}${num}) ${RED}${src}${RESET}"
    done || echo -e "${YELLOW}无手动封禁规则${RESET}"

    echo -e "${BLUE}==============================${RESET}"
    echo -e "${BLUE}按任意键返回菜单...${RESET}"
    read -n1 -s
}

#===== 实时查看日志 =====
function tail_log() {
    echo -e "${GREEN}实时查看 /var/log/fail2ban.log（Ctrl+C 退出）${RESET}"
    sudo tail -n 50 -F /var/log/fail2ban.log
    echo
    echo -e "${BLUE}按任意键返回菜单...${RESET}"
    read -n1 -s
}

#===== 手动封禁/解封 IP =====
function manual_ban() {
    view_ssh_status
    local ssh_port ip_addr action
    ssh_port=$(get_ssh_port)

    echo -e "${YELLOW}操作选项：${RESET}"
    echo -e "${YELLOW}0. 返回${RESET}"
    echo -e "${YELLOW}00. 手动封禁 IP（仅限 SSH 端口 $ssh_port）${RESET}"
    echo -e "${YELLOW}1-99. 解封对应序号的 IP${RESET}"
    read -p "请输入选择 (0/00 或 1-99): " action

    if [ "$action" == "0" ]; then
        return
    fi

    if [ "$action" == "00" ]; then
        read -p "请输入要封禁的 IP: " ip_addr
        echo -e "${BLUE}添加 iptables 规则，DROP 来自 $ip_addr 的 SSH 流量...${RESET}"
        sudo iptables -I INPUT -s "$ip_addr" -p tcp --dport "$ssh_port" -j DROP
        sudo netfilter-persistent save
        echo -e "${GREEN}已封禁 $ip_addr。${RESET}"
        read -n1 -s -p "按任意键返回菜单..."
        return
    fi

    if [[ "$action" =~ ^[0-9]+$ ]] && [ "$action" -ge 1 ]; then
        # 获取手动封禁规则列表
        mapfile -t rules < <(sudo iptables -L INPUT -n --line-numbers | grep "DROP" | grep "dpt:$ssh_port")
        idx=$((action-1))
        if [ "$idx" -ge "${#rules[@]}" ]; then
            echo -e "${RED}无效的序号！${RESET}"
            read -n1 -s -p "按任意键返回菜单..."
            return
        fi
        line="${rules[$idx]}"
        num=$(echo $line | awk '{print $1}')
        ip_addr=$(echo $line | awk '{print $4}')
        read -p "确定要解封 $ip_addr 吗？(y/n): " confirm
        if [[ "$confirm" =~ [Yy] ]]; then
            echo -e "${BLUE}删除 iptables 规则 #$num ...${RESET}"
            sudo iptables -D INPUT "$num"
            sudo netfilter-persistent save
            echo -e "${GREEN}已解封 $ip_addr。${RESET}"
        else
            echo -e "${YELLOW}已取消操作。${RESET}"
        fi
    else
        echo -e "${RED}无效输入！${RESET}"
    fi

    read -n1 -s -p "按任意键返回菜单..."
}

#===== 查看配置文件 =====
function view_config() {
    echo -e "${BLUE}—— /etc/fail2ban/jail.local ——${RESET}"
    if [ -f /etc/fail2ban/jail.local ]; then
        sudo sed -n '1,200p' /etc/fail2ban/jail.local
    else
        echo -e "${YELLOW}jail.local 文件不存在${RESET}"
    fi
    echo -e "${BLUE}—— /etc/ssh/sshd_config ——${RESET}"
    if [ -f /etc/ssh/sshd_config ]; then
        sudo sed -n '1,200p' /etc/ssh/sshd_config
    else
        echo -e "${YELLOW}sshd_config 文件不存在${RESET}"
    fi
    echo
    read -n1 -s -p "按任意键返回菜单..."
}

#===== 卸载并清理 =====
function uninstall_fail2ban() {
    echo -e "${GREEN}开始卸载 fail2ban + iptables 并清理残留…${RESET}"
    sudo systemctl stop fail2ban
    sudo apt-get remove --purge -y fail2ban rsyslog iptables-persistent

    # 删除所有 DROP SSH 规则
    ssh_port=$(get_ssh_port)
    while sudo iptables -C INPUT -p tcp --dport "$ssh_port" -j DROP &>/dev/null; do
        sudo iptables -D INPUT -p tcp --dport "$ssh_port" -j DROP
    done
    sudo netfilter-persistent save

    # 清理配置和日志
    sudo rm -rf /etc/fail2ban
    sudo rm -f /var/log/fail2ban.log

    echo -e "${GREEN}卸载并清理完成。${RESET}"
    read -n1 -s -p "按任意键返回菜单…"
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
