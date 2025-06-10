#!/bin/bash
#==================================================
# Fail2ban 安装与管理脚本
# 适用于 Debian/Ubuntu 系统
#==================================================

#===== 颜色变量 =====
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"  # 无颜色

#===== 显示主菜单 =====
function show_menu() {
    clear
    # fail2ban 安装状态
    if dpkg -l | grep -qw fail2ban; then
        install_status="已安装"
    else
        install_status="未安装"
    fi
    # iptables 运行状态
    if systemctl is-active --quiet iptables; then
        ipt_status="运行中"
    else
        ipt_status="未运行"
    fi

    echo -e "${BLUE}==============================${RESET}"
    echo -e "${GREEN}      Fail2ban 管理脚本       ${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -e "Fail2ban: ${YELLOW}${install_status}${RESET}    iptables: ${YELLOW}${ipt_status}${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -e "${YELLOW}1. 安装 fail2ban${RESET}"
    echo -e "${YELLOW}2. 查看 fail2ban 状态${RESET}"
    echo -e "${YELLOW}3. 查看 SSH 服务封禁情况${RESET}"
    echo -e "${YELLOW}4. 查看配置文件${RESET}"
    echo -e "${YELLOW}5. 实时查看 fail2ban 日志${RESET}"
    echo -e "${YELLOW}6. 手动封禁/解封 IP 地址${RESET}"
    echo -e "${YELLOW}7. 卸载 fail2ban 并清理日志${RESET}"
    echo -e "${YELLOW}0. 退出${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -n "请选择操作: "
}

#===== 查看 fail2ban 原始状态 =====
function original_view_status() {
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}fail2ban 当前状态：已启动${RESET}"
    else
        echo -e "${RED}fail2ban 当前状态：未运行${RESET}"
    fi
    sudo fail2ban-client status 2>/dev/null
}

#===== 安装 fail2ban =====
function install_fail2ban() {
    echo -e "${GREEN}开始安装 fail2ban...${RESET}"
    echo -e "${BLUE}更新系统软件包...${RESET}"
    sudo apt-get update && sudo apt-get upgrade -y
    echo -e "${BLUE}检查并安装依赖：rsyslog 和 iptables...${RESET}"
    sudo apt-get install -y rsyslog iptables

    echo -e "${BLUE}检测当前系统环境...${RESET}"
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${GREEN}系统: $NAME $VERSION${RESET}"
    else
        echo -e "${RED}无法检测系统环境，可能不是 Debian/Ubuntu 系统。${RESET}"
    fi

    ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n 1)
    if [ -z "$ssh_port" ]; then
        echo -e "${YELLOW}未能自动检测到 SSH 端口，请手动输入。${RESET}"
        read -p "请输入 SSH 端口: " ssh_port
        read -p "确认 SSH 端口为 $ssh_port (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${RED}SSH 端口未确认，退出安装。${RESET}"
            return
        fi
    else
        echo -e "${GREEN}检测到 SSH 端口: $ssh_port${RESET}"
    fi

    echo -e "${BLUE}安装 fail2ban...${RESET}"
    sudo apt-get install -y fail2ban

    echo -e "${BLUE}生成 fail2ban 配置文件...${RESET}"
    sudo mkdir -p /etc/fail2ban
    [ -f /etc/fail2ban/jail.conf ] && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak

    sudo bash -c "cat > /etc/fail2ban/jail.local" <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 3600
findtime = 300
maxretry = 5

[sshd]
enabled = true
port    = $ssh_port
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF

    echo -e "${GREEN}生成的 fail2ban 配置文件内容如下:${RESET}"
    cat /etc/fail2ban/jail.local

    sudo systemctl start fail2ban
    sudo systemctl enable fail2ban
    echo -e "${GREEN}fail2ban 已启动并设置为开机自启。${RESET}"

    echo -e "${BLUE}设置定时任务，每十五天清理一次 fail2ban 日志...${RESET}"
    cron_job="0 0 */15 * * root echo '' > /var/log/fail2ban.log"
    (sudo crontab -l 2>/dev/null | grep -v 'fail2ban.log'; echo "$cron_job") | sudo crontab -

    echo -e "${BLUE}当前 fail2ban 运行状态:${RESET}"
    original_view_status

    echo -e "${GREEN}fail2ban 安装完成。${RESET}"
}

#===== 查看 fail2ban 状态 =====
function view_fail2ban_status() {
    echo -e "${GREEN}当前 fail2ban 状态:${RESET}"
    sudo service fail2ban status
    echo -e "${YELLOW}按任意键返回菜单...${RESET}"
    read -n 1 -s
}

#===== 查看 SSH 封禁状态及封禁时间 =====
function view_ssh_status() {
    echo -e "${GREEN}SSH 服务封禁情况：${RESET}"
    # 获取当前被封禁的 IP 列表
    ips=$(sudo fail2ban-client status sshd 2>/dev/null | grep 'Banned IP list' | cut -d: -f2)
    # 清理首尾空格
    ips=$(echo $ips | sed 's/^ *//;s/ *$//')
    if [ -z "$ips" ]; then
        echo -e "${YELLOW}当前没有被封禁的 IP。${RESET}"
        return
    fi

    echo -e "${GREEN}当前被封禁的 IP 及封禁时间：${RESET}"
    printf "%-20s %-20s\n" "IP 地址" "封禁时间"
    echo "$ips" | tr ',' '\n' | while read ip; do
        [ -z "$ip" ] && continue
        # 从日志中找最后一次 Ban 记录
        ban_time=$(sudo grep "Ban $ip" /var/log/fail2ban.log | tail -n1 | awk '{print $1 " " $2}')
        printf "%-20s %-20s\n" "$ip" "${ban_time:-未知}"
    done
}

#===== 查看配置文件 =====
function view_config() {
    echo -e "${GREEN}fail2ban 配置文件 (/etc/fail2ban/jail.local) 内容：${RESET}"
    if [ -f /etc/fail2ban/jail.local ]; then
        cat /etc/fail2ban/jail.local
    else
        echo -e "${RED}/etc/fail2ban/jail.local 文件不存在！${RESET}"
    fi
}

#===== 实时查看 fail2ban 日志（已修复卡死问题） =====
function tail_log() {
    echo -e "${GREEN}实时查看 fail2ban 日志（按 Ctrl+C 退出）:${RESET}"
    if [ -f /var/log/fail2ban.log ]; then
        sudo tail -n 50 -F /var/log/fail2ban.log
    else
        echo -e "${RED}未找到 /var/log/fail2ban.log 日志文件！${RESET}"
    fi
}

#===== 手动封禁或解封 IP =====
function manual_ban() {
    echo -e "${GREEN}手动封禁/解封 IP 地址${RESET}"
    read -p "请输入目标 IP 地址: " ip_addr
    echo -e "${YELLOW}请选择操作：1. 封禁   2. 解封${RESET}"
    read -p "请选择操作 (1/2): " action
    if [ "$action" == "1" ]; then
        echo -e "${BLUE}正在封禁 IP: $ip_addr ...${RESET}"
        sudo fail2ban-client set sshd banip "$ip_addr" 2>/dev/null
        echo -e "${GREEN}IP $ip_addr 已被封禁。${RESET}"
    elif [ "$action" == "2" ]; then
        echo -e "${BLUE}正在解封 IP: $ip_addr ...${RESET}"
        sudo fail2ban-client set sshd unbanip "$ip_addr" 2>/dev/null
        echo -e "${GREEN}IP $ip_addr 已被解封。${RESET}"
    else
        echo -e "${RED}无效操作，请选择 1 或 2。${RESET}"
    fi
}

#===== 卸载并清理 fail2ban =====
function uninstall_fail2ban() {
    echo -e "${GREEN}正在卸载 fail2ban 并清理相关配置及日志...${RESET}"
    sudo systemctl stop fail2ban
    sudo apt-get remove --purge -y fail2ban
    sudo rm -rf /etc/fail2ban
    sudo rm -f /var/log/fail2ban.log
    sudo crontab -l 2>/dev/null | grep -v 'fail2ban.log' | sudo crontab -
    echo -e "${GREEN}fail2ban 已卸载，相关日志及配置文件已清理。${RESET}"
}

#===== 主菜单循环 =====
while true; do
    show_menu
    read choice
    case $choice in
        1) install_fail2ban ;;
        2) view_fail2ban_status ;;
        3) view_ssh_status ;;
        4) view_config ;;
        5) tail_log ;;
        6) manual_ban ;;
        7) uninstall_fail2ban ;;
        0)
            echo -e "${GREEN}退出脚本。${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新选择。${RESET}"
            ;;
    esac
    if [ "$choice" != "2" ]; then
        echo -e "${YELLOW}按任意键返回主菜单...${RESET}"
        read -n 1 -s
    fi
done
