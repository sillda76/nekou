#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

DEFAULT_BANTIME=3600  # 封禁时间设置为 3600 秒（1 小时）
DEFAULT_MAXRETRY=6    # 最大重试次数设置为 6 次
DEFAULT_FINDTIME=600  # 检测时间保持默认的 600 秒（10 分钟）
DEFAULT_IGNOREIP="127.0.0.1/8 ::1"

BANTIME=$DEFAULT_BANTIME
MAXRETRY=$DEFAULT_MAXRETRY
FINDTIME=$DEFAULT_FINDTIME
IGNOREIP="$DEFAULT_IGNOREIP"

log_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

check_fail2ban_installed() {
    if command -v fail2ban-client &> /dev/null; then
        log_warn "fail2ban 已安装。"
        read -p "是否卸载并重新安装 fail2ban？(y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            log_info "正在卸载 fail2ban..."
            apt purge -y fail2ban
            log_info "fail2ban 已卸载。"
        else
            log_info "退出安装。"
            exit 0  # 用户输入 n，退出脚本
        fi
    else
        log_info "fail2ban 未安装，继续安装流程。"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

check_system() {
    if ! command -v apt-get &> /dev/null; then
        log_error "此脚本仅支持 Debian/Ubuntu 系统"
        exit 1
    fi
}

check_system_version() {
    if ! command -v iptables &> /dev/null; then
        log_info "正在安装 iptables..."
        apt-get install -y iptables
    else
        log_info "iptables 已安装，跳过安装步骤。"
    fi

    if [[ -f /etc/debian_version ]]; then
        DEBIAN_VERSION=$(cat /etc/debian_version)
        if [[ $DEBIAN_VERSION =~ ^12 ]]; then
            log_info "正在安装 rsyslog..."
            apt-get install -y rsyslog
        fi
    fi
}

get_ssh_port() {
    SSH_PORT=$(ss -tnlp | awk '/sshd/ && /LISTEN/ {print $4}' | awk -F: '{print $NF}' | head -1)
    if [ -z "$SSH_PORT" ]; then
        SSH_PORT=22
        log_warn "未检测到自定义SSH端口，使用默认端口22。"
    else
        log_info "检测到的SSH端口: $SSH_PORT"
    fi
}

install_fail2ban() {
    log_info "正在更新软件包列表..."
    apt-get update
    check_system_version
    log_info "正在安装 fail2ban..."
    apt-get install -y fail2ban
}

configure_fail2ban() {
    log_info "正在配置 fail2ban..."

    LOGPATH=""
    for logfile in "/var/log/auth.log" "/var/log/secure" "/var/log/messages"; do
        if [[ -f "$logfile" ]]; then
            LOGPATH="$logfile"
            log_info "检测到 SSH 日志文件路径: $LOGPATH"
            break
        fi
    done

    if [[ -z "$LOGPATH" ]]; then
        log_warn "未找到 SSH 日志文件，跳过日志文件配置。"
    fi

    # 获取 SSH 端口
    get_ssh_port

    # 生成配置文件
    cat > /etc/fail2ban/jail.local << EOL
[DEFAULT]
allowipv6 = auto
bantime = $BANTIME
findtime = $FINDTIME
maxretry = $MAXRETRY
ignoreip = $IGNOREIP
banaction = iptables-multiport
loglevel = INFO
logtarget = /var/log/fail2ban.log

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = $LOGPATH
maxretry = $MAXRETRY
findtime = $FINDTIME
bantime = $BANTIME
EOL

    if ! fail2ban-client -t; then
        log_error "fail2ban 配置文件校验失败"
        exit 1
    fi
}

start_service() {
    log_info "正在启动 fail2ban 服务..."
    systemctl start fail2ban
    systemctl enable fail2ban

    if systemctl is-active --quiet fail2ban; then
        log_info "fail2ban 服务已成功启动"
    else
        log_error "fail2ban 服务启动失败"
        exit 1
    fi
}

setup_cron_job() {
    log_info "正在设置每7天清理 fail2ban 日志的定时任务..."
    CRON_JOB="0 0 */7 * * root /usr/bin/bash -c '> /var/log/fail2ban.log'"
    if ! grep -q "$CRON_JOB" /etc/crontab; then
        echo "$CRON_JOB" >> /etc/crontab
        log_info "定时任务已添加。"
    fi
}

show_status() {
    echo -e "${GREEN}[信息]${NC} 正在查看 fail2ban 状态..."
    fail2ban-client status
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -r -s -n 1  # 等待用户按任意键
}

show_ssh_status() {
    echo -e "${GREEN}[信息]${NC} 正在查看 SSH 状态..."
    fail2ban-client status sshd
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -r -s -n 1  # 等待用户按任意键
}

show_config() {
    echo -e "${GREEN}[信息]${NC} 正在查看 fail2ban 配置..."
    cat /etc/fail2ban/jail.local
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -r -s -n 1  # 等待用户按任意键
}

show_logs() {
    echo -e "${GREEN}[信息]${NC} 正在查看 fail2ban 日志..."
    tail -f /var/log/fail2ban.log
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -r -s -n 1  # 等待用户按任意键
}

ban_ip() {
    read -p "请输入要封禁的 IP 地址（输入 0 返回菜单）: " ip
    if [[ "$ip" == "0" ]]; then
        return
    fi
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        fail2ban-client set sshd banip "$ip"
        echo -e "${GREEN}[信息]${NC} IP 地址 $ip 已封禁。"
    else
        echo -e "${RED}[错误]${NC} 输入的 IP 地址无效。"
    fi
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -r -s -n 1  # 等待用户按任意键
}

unban_ip() {
    read -p "请输入要解封的 IP 地址（输入 0 返回菜单）: " ip
    if [[ "$ip" == "0" ]]; then
        return
    fi
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        fail2ban-client set sshd unbanip "$ip"
        echo -e "${GREEN}[信息]${NC} IP 地址 $ip 已解封。"
    else
        echo -e "${RED}[错误]${NC} 输入的 IP 地址无效。"
    fi
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -r -s -n 1  # 等待用户按任意键
}

uninstall_fail2ban() {
    log_info "正在卸载 fail2ban..."
    apt purge -y fail2ban

    # 删除配置文件
    if [[ -d /etc/fail2ban ]]; then
        log_info "正在删除 fail2ban 配置文件..."
        rm -rf /etc/fail2ban
    fi

    # 删除日志文件
    if [[ -f /var/log/fail2ban.log ]]; then
        log_info "正在删除 fail2ban 日志文件..."
        rm -f /var/log/fail2ban.log
    fi

    # 删除定时任务
    if grep -q "fail2ban" /etc/crontab; then
        log_info "正在删除 fail2ban 定时任务..."
        sed -i '/fail2ban/d' /etc/crontab
    fi

    log_info "fail2ban 已完全卸载。"
}

interactive_menu() {
    while true; do
        echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║          ${BOLD}fail2ban 安装与管理脚本${NC}       ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${GREEN}1. 安装 fail2ban${NC}    - 安装并配置 fail2ban"
        echo -e "${GREEN}2. 查看状态${NC}       - 查看 fail2ban 的运行状态"
        echo -e "${GREEN}3. 查看 SSH 状态${NC}  - 查看 SSH 服务的封禁情况"
        echo -e "${GREEN}4. 查看配置${NC}       - 查看 fail2ban 的配置文件"
        echo -e "${GREEN}5. 查看日志${NC}       - 实时查看 fail2ban 日志"
        echo -e "${YELLOW}6. 封禁 IP${NC}        - 手动封禁指定 IP 地址"
        echo -e "${YELLOW}7. 解封 IP${NC}        - 手动解封指定 IP 地址"
        echo -e "${RED}8. 卸载 fail2ban${NC}  - 卸载 fail2ban 服务"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        echo -e "${PURPLE}0. 退出脚本${NC}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        read -p "请输入选项编号 (0-8): " choice
        case "$choice" in
            1)
                log_info "开始安装 fail2ban..."
                check_root
                check_system
                install_fail2ban
                configure_fail2ban
                start_service
                setup_cron_job
                log_info "fail2ban 安装完成！"
                echo -e "${YELLOW}按任意键返回菜单...${NC}"
                read -r -s -n 1
                ;;
            2) show_status ;;
            3) show_ssh_status ;;
            4) show_config ;;
            5) show_logs ;;
            6) ban_ip ;;
            7) unban_ip ;;
            8)
                uninstall_fail2ban
                exit 0
                ;;
            0) exit 0 ;;
            *) echo -e "${RED}错误：无效的选项，请重新输入。${NC}" ;;
        esac
    done
}

main() {
    interactive_menu
}

main
