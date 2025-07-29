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
    if dpkg -l | grep -qw fail2ban; then
        install_status="已安装"
        ssh_port=$(grep -E '^port\s*=' /etc/fail2ban/jail.local 2>/dev/null | awk -F= '{gsub(/ /,"",$2); print $2}')
        [ -z "$ssh_port" ] && ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
        port_display="SSH端口: ${YELLOW}${ssh_port:-未知}${RESET}"
    else
        install_status="未安装"
        port_display=""
    fi

    echo -e "${BLUE}==============================${RESET}"
    echo -e "${GREEN}      Fail2ban 管理脚本       ${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -e "Fail2ban: ${YELLOW}${install_status}${RESET}    ${port_display}"
    echo -e "${BLUE}==============================${RESET}"
    echo -e "${YELLOW}1. 安装 fail2ban${RESET}"
    echo -e "${YELLOW}2. 查看 fail2ban 状态${RESET}"
    echo -e "${YELLOW}3. 查看 SSH 服务封禁情况${RESET}"
    echo -e "${YELLOW}4. 查看配置文件${RESET}"
    echo -e "${YELLOW}5. 实时查看 fail2ban 日志${RESET}"
    echo -e "${YELLOW}6. 卸载 fail2ban 并清理日志${RESET}"
    echo -e "${YELLOW}0. 退出${RESET}"
    echo -e "${BLUE}==============================${RESET}"
    echo -n "请选择操作: "
}

#===== 查看 fail2ban 状态 =====
function view_fail2ban_status() {
    echo -e "${GREEN}当前 fail2ban 状态:${RESET}"
    sudo systemctl status fail2ban
}

#===== 安装 fail2ban =====
function install_fail2ban() {
    echo -e "${GREEN}开始安装 fail2ban...${RESET}"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y rsyslog iptables

    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${GREEN}系统: $NAME $VERSION${RESET}"
    else
        echo -e "${RED}无法检测系统环境，可能不是 Debian/Ubuntu 系统。${RESET}"
    fi

    ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
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

    sudo apt-get install -y fail2ban

    [ -f /etc/fail2ban/jail.conf ] && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak

    sudo bash -c "cat > /etc/fail2ban/jail.local" <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 600
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

    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban

    echo -e "${GREEN}fail2ban 已启动并设置为开机自启。${RESET}"

    #（可选）不推荐清空日志，以下语句注释掉
    echo -e "${BLUE}设置定时任务，每15天清空 fail2ban 日志...${RESET}"
    cron_job="0 0 */15 * * root echo '' > /var/log/fail2ban.log"
    (sudo crontab -l 2>/dev/null | grep -v 'fail2ban.log'; echo "$cron_job") | sudo crontab -

    view_fail2ban_status
}

#===== 查看 SSH 封禁情况 =====
function view_ssh_status() {
    echo -e "${GREEN}SSH 服务封禁情况：${RESET}"
    raw_ips=$(sudo fail2ban-client status sshd 2>/dev/null | grep 'Banned IP list' | cut -d: -f2)
    ips=( $(echo $raw_ips | sed 's/^ *//;s/ *$//' | tr ',' ' ') )
    if [ ${#ips[@]} -eq 0 ] || [ -z "${ips[0]}" ]; then
        echo -e "${YELLOW}当前没有被封禁的 IP。${RESET}"
    else
        echo -e "${GREEN}当前被封禁的 IP 及封禁时间：${RESET}"
        printf "%-5s %-20s %-20s\n" "序号" "IP 地址" "封禁时间"
        for i in "${!ips[@]}"; do
            ip=${ips[i]}
            ban_time=$(sudo grep "Ban $ip" /var/log/fail2ban.log | tail -n1 | awk '{print $1 " " $2}')
            printf "${BLUE}%-5s${RESET} ${RED}%-20s${RESET} ${YELLOW}%-20s${RESET}\n" \
                "$((i+1))" "$ip" "${ban_time:-未知}"
        done
    fi

    echo -e "${BLUE}----------------------------------------${RESET}"
    echo -e "${YELLOW}输入序号解封对应 IP，输入99手动封禁，输入0返回主菜单${RESET}"
    read -p "请选择: " sel
    case $sel in
        0) return ;;
        99)
            read -p "请输入要封禁的 IP 地址: " banip
            sudo fail2ban-client set sshd banip "$banip"
            echo -e "${GREEN}IP $banip 已被手动封禁。${RESET}"
            ;;
        ''|*[!0-9]*)
            echo -e "${RED}无效输入。${RESET}" ;;
        *)
            if [ "$sel" -ge 1 ] && [ "$sel" -le "${#ips[@]}" ]; then
                target_ip=${ips[$((sel-1))]}
                sudo fail2ban-client set sshd unbanip "$target_ip"
                echo -e "${GREEN}IP $target_ip 已被解封。${RESET}"
            else
                echo -e "${RED}无效序号。${RESET}"
            fi
            ;;
    esac
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

#===== 实时查看日志 =====
function tail_log() {
    echo -e "${GREEN}实时查看 fail2ban 日志（按 Ctrl+C 退出）:${RESET}"
    if [ -f /var/log/fail2ban.log ]; then
        sudo tail -n 50 -F /var/log/fail2ban.log
    else
        echo -e "${RED}未找到 /var/log/fail2ban.log 日志文件！${RESET}"
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

#===== 主循环 =====
while true; do
    show_menu
    read choice
    case $choice in
        1) install_fail2ban ;;
        2) view_fail2ban_status ;;
        3) view_ssh_status ;;
        4) view_config ;;
        5) tail_log ;;
        6) uninstall_fail2ban ;;
        0)
            echo -e "${GREEN}退出脚本。${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新选择。${RESET}"
            ;;
    esac

    if [ "$choice" != "0" ]; then
        echo -e "${YELLOW}按任意键继续...${RESET}"
        read -n1 -s
    fi
done
