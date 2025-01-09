#!/bin/bash

# 设置错误时退出
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_BANTIME=1800       # 封禁时间 30 分钟
DEFAULT_MAXRETRY=4         # 最大尝试次数 4 次
DEFAULT_FINDTIME=600       # 检测时间窗口 10 分钟
DEFAULT_IGNOREIP="127.0.0.1/8 ::1"
SSH_CONFIG_PATH="/etc/ssh/sshd_config"  # SSH 配置文件路径
LOG_FILE="/var/log/install_fail2ban.log"  # 脚本日志文件

# 全局变量
BANTIME=$DEFAULT_BANTIME
MAXRETRY=$DEFAULT_MAXRETRY
FINDTIME=$DEFAULT_FINDTIME
IGNOREIP="$DEFAULT_IGNOREIP"

# 日志函数
log_info() {
    echo -e "${GREEN}[信息]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [信息] $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [警告] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [错误] $1" >> "$LOG_FILE"
    exit 1
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
    fi
}

# 检查系统
check_system() {
    if ! command -v apt-get &> /dev/null; then
        log_error "此脚本仅支持 Debian/Ubuntu 系统"
    fi
}

# 安装 fail2ban
install_fail2ban() {
    log_info "正在更新软件包列表..."
    apt-get update

    log_info "正在安装 fail2ban..."
    apt-get install -y fail2ban
}

# 获取当前 SSH 端口
get_ssh_port() {
    local ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | awk -F':' '{print $NF}')
    if [[ -z "$ssh_port" ]]; then
        log_error "无法检测到 SSH 端口"
    fi
    echo "$ssh_port"
}

# 配置 fail2ban
configure_fail2ban() {
    log_info "正在配置 fail2ban..."

    # 获取当前 SSH 端口
    local ssh_port=$(get_ssh_port)
    log_info "检测到当前 SSH 端口: $ssh_port"

    # 备份原配置文件
    if [ -f /etc/fail2ban/jail.local ]; then
        log_warn "正在备份现有的 jail.local 文件..."
        cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d%H%M%S)
    fi

    # 创建主配置文件
    cat > /etc/fail2ban/jail.local << EOL
[DEFAULT]
bantime = $BANTIME
findtime = $FINDTIME
maxretry = $MAXRETRY
ignoreip = $IGNOREIP
banaction = iptables-multiport
loglevel = INFO
logtarget = /var/log/fail2ban.log

[sshd]
enabled = true
port = $ssh_port
filter = sshd
logpath = /var/log/auth.log
maxretry = $MAXRETRY
findtime = $FINDTIME
bantime = $BANTIME
EOL

    # 校验配置文件
    if ! fail2ban-client -t; then
        log_error "fail2ban 配置文件校验失败，请检查配置"
    fi
}

# 启动服务
start_service() {
    log_info "正在启动 fail2ban 服务..."
    systemctl start fail2ban
    systemctl enable fail2ban

    if systemctl is-active --quiet fail2ban; then
        log_info "fail2ban 服务已成功启动"
    else
        log_error "fail2ban 服务启动失败"
    fi
}

# 显示状态信息
show_status() {
    log_info "正在检查 fail2ban 状态..."
    fail2ban-client status

    log_info "fail2ban 安装和配置已完成！"
    echo -e "\nSSH 保护配置："
    echo "- 封禁时间: $BANTIME 秒"
    echo "- 最大尝试次数: $MAXRETRY 次"
    echo "- 检测时间窗口: $FINDTIME 秒"
    echo "- 忽略的 IP 地址: $IGNOREIP"
    echo -e "\n常用命令："
    echo "- 查看状态: fail2ban-client status"
    echo "- 查看 SSH 监狱状态: fail2ban-client status sshd"
    echo "- 封禁 IP: fail2ban-client set sshd banip <IP>"
    echo "- 解封 IP: fail2ban-client set sshd unbanip <IP>"
    echo "- 查看日志: tail -f /var/log/fail2ban.log"
    echo "- 查看自定义配置文件: cat /etc/fail2ban/jail.local"
}

# 主函数
main() {
    check_root
    check_system

    # 安装和配置 fail2ban
    install_fail2ban
    configure_fail2ban
    start_service
    show_status
}

# 运行主函数
main
