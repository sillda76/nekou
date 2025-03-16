#!/bin/bash
#==================================================
# Fail2ban 安装与管理脚本
# 适用于 Debian/Ubuntu 系统
# 功能：
#  1. 安装 fail2ban（更新系统、检查依赖、获取 SSH 端口、生成配置文件、安装、启动及定时清理日志）
#  2. 查看 fail2ban 运行状态
#  3. 查看 SSH 服务的封禁情况
#  4. 查看 fail2ban 配置文件
#  5. 实时查看 fail2ban 日志（支持退出按键）
#  6. 手动封禁/解封 IP 地址
#  7. 卸载 fail2ban 并清理相关日志及配置文件
#==================================================

# 定义颜色变量（美化界面提示）
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"  # 无颜色

# 显示主菜单
function show_menu() {
    echo -e "${BLUE}==============================${NC}"
    echo -e "${GREEN}      Fail2ban 管理脚本       ${NC}"
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

# 选项1：安装 fail2ban
function install_fail2ban() {
    echo -e "${GREEN}开始安装 fail2ban...${NC}"
    
    # 更新系统软件包
    echo -e "${BLUE}更新系统软件包...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y

    # 检查并安装所需依赖：rsyslog 和 iptables
    echo -e "${BLUE}检查并安装依赖：rsyslog 和 iptables...${NC}"
    sudo apt-get install -y rsyslog iptables

    # 检测当前系统环境
    echo -e "${BLUE}检测当前系统环境...${NC}"
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${GREEN}系统: $NAME $VERSION${NC}"
    else
        echo -e "${RED}无法检测系统环境，可能不是 Debian/Ubuntu 系统。${NC}"
    fi

    # 检测 SSH 端口
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

    # 编辑 fail2ban 配置文件
    echo -e "${BLUE}生成 fail2ban 配置文件...${NC}"
    # 备份原始 jail.conf 文件（如果存在）
    [ -f /etc/fail2ban/jail.conf ] && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak

    # 生成本地配置文件 /etc/fail2ban/jail.local
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
# 释放封禁的时间（仅作注释参考，实际释放时间由 fail2ban 内部机制控制）
# unban_after = 7200

[sshd]
enabled = true
port    = $ssh_port
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF

    # 显示生成的配置文件内容供确认
    echo -e "${GREEN}生成的 fail2ban 配置文件内容如下:${NC}"
    cat /etc/fail2ban/jail.local

    # 安装 fail2ban
    echo -e "${BLUE}安装 fail2ban...${NC}"
    sudo apt-get install -y fail2ban

    # 启动 fail2ban 并设置开机自启
    sudo systemctl start fail2ban
    sudo systemctl enable fail2ban
    echo -e "${GREEN}fail2ban 已启动并设置为开机自启。${NC}"

    # 设置每十五天清理一次 fail2ban 日志的定时任务
    echo -e "${BLUE}设置定时任务，每十五天清理一次 fail2ban 日志...${NC}"
    cron_job="0 0 */15 * * root echo '' > /var/log/fail2ban.log"
    (sudo crontab -l 2>/dev/null; echo "$cron_job") | sudo crontab -

    echo -e "${GREEN}fail2ban 安装及配置完毕。${NC}"
}

# 选项2：查看 fail2ban 状态
function view_status() {
    echo -e "${GREEN}fail2ban 当前状态：${NC}"
    sudo fail2ban-client status
}

# 选项3：查看 SSH 服务封禁情况
function view_ssh_status() {
    echo -e "${GREEN}SSH 服务封禁情况：${NC}"
    sudo fail2ban-client status sshd
}

# 选项4：查看配置文件
function view_config() {
    echo -e "${GREEN}fail2ban 配置文件 (/etc/fail2ban/jail.local) 内容：${NC}"
    cat /etc/fail2ban/jail.local
}

# 选项5：实时查看 fail2ban 日志，并支持退出
function tail_log() {
    echo -e "${GREEN}实时查看 fail2ban 日志（按 q 键退出）:${NC}"
    # 使用 less +F 实现实时查看并支持退出
    sudo less +F /var/log/fail2ban.log
}

# 选项6：手动封禁/解封 IP 地址
function manual_ban() {
    echo -e "${GREEN}手动封禁/解封 IP 地址${NC}"
    read -p "请输入目标 IP 地址: " ip_addr
    echo -e "${YELLOW}请选择操作：1. 封禁   2. 解封${NC}"
    read -p "请选择操作 (1/2): " action
    if [ "$action" == "1" ]; then
        echo -e "${BLUE}正在封禁 IP: $ip_addr ...${NC}"
        sudo fail2ban-client set sshd banip $ip_addr
        echo -e "${GREEN}IP $ip_addr 已被封禁。${NC}"
    elif [ "$action" == "2" ]; then
        echo -e "${BLUE}正在解封 IP: $ip_addr ...${NC}"
        sudo fail2ban-client set sshd unbanip $ip_addr
        echo -e "${GREEN}IP $ip_addr 已被解封。${NC}"
    else
        echo -e "${RED}无效操作，请选择 1 或 2。${NC}"
    fi
}

# 选项7：卸载 fail2ban 并清理日志
function uninstall_fail2ban() {
    echo -e "${GREEN}正在卸载 fail2ban 并清理相关配置及日志...${NC}"
    sudo systemctl stop fail2ban
    sudo apt-get remove --purge -y fail2ban
    sudo rm -rf /etc/fail2ban
    sudo rm -f /var/log/fail2ban.log
    # 清理定时任务中关于 fail2ban 日志的行
    sudo crontab -l | grep -v 'fail2ban.log' | sudo crontab -
    echo -e "${GREEN}fail2ban 已卸载，相关日志及配置文件已清理。${NC}"
}

# 主循环：显示菜单并处理用户输入
while true; do
    show_menu
    read choice
    case $choice in
        1)
            install_fail2ban
            ;;
        2)
            view_status
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
    # 提示用户按任意键返回主菜单
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1 -s
done
