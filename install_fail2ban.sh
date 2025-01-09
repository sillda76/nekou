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

# 全局变量
BANTIME=$DEFAULT_BANTIME
MAXRETRY=$DEFAULT_MAXRETRY
FINDTIME=$DEFAULT_FINDTIME
IGNOREIP="$DEFAULT_IGNOREIP"

# 日志函数
log_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

# 检查系统
check_system() {
    if ! command -v apt-get &> /dev/null; then
        log_error "此脚本仅支持 Debian/Ubuntu 系统"
        exit 1
    fi
}

# 安装 fail2ban
install_fail2ban() {
    log_info "正在更新软件包列表..."
    apt-get update

    log_info "正在安装 fail2ban..."
    apt-get install -y fail2ban
}

# 配置 fail2ban
configure_fail2ban() {
    log_info "正在配置 fail2ban..."

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
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = $MAXRETRY
findtime = $FINDTIME
bantime = $BANTIME
EOL
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
        exit 1
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
}

# 安装其他软件
install_other_software() {
    log_info "正在安装其他软件..."
    # 这里可以添加你需要安装的其他软件
    # 例如：apt-get install -y nginx mysql-server
}

# 主函数
main() {
    check_root
    check_system

    # 安装其他软件
    install_other_software

    # 安装和配置 fail2ban
    install_fail2ban
    configure_fail2ban
    start_service
    show_status
}

# 运行主函数
main
