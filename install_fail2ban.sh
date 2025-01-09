#!/bin/bash

# 设置错误时退出
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'  # 新增蓝色
NC='\033[0m' # No Color

# 默认配置
DEFAULT_BANTIME=1800       # 封禁时间 30 分钟
DEFAULT_MAXRETRY=5         # 最大尝试次数 5 次
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

# 检查系统版本并安装 rsyslog（仅适用于 Debian 12 及以上版本）
check_system_version() {
    if [[ -f /etc/debian_version ]]; then
        DEBIAN_VERSION=$(cat /etc/debian_version)
        if [[ $DEBIAN_VERSION =~ ^12 ]]; then
            log_info "检测到系统为 Debian 12 及以上版本，正在安装 rsyslog..."
            apt-get install -y rsyslog
        else
            log_warn "系统版本低于 Debian 12，跳过 rsyslog 安装。"
        fi
    else
        log_warn "非 Debian 系统，跳过 rsyslog 安装。"
    fi
}

# 安装 fail2ban
install_fail2ban() {
    log_info "正在更新软件包列表..."
    apt-get update

    # 在更新完系统软件包后检测并安装 rsyslog
    check_system_version

    log_info "正在安装 fail2ban..."
    apt-get install -y fail2ban
}

# 获取当前 SSH 端口
get_ssh_port() {
    local ssh_port

    # 从 SSH 配置文件中获取端口
    ssh_port=$(grep -E "^#?Port\s+[0-9]+" /etc/ssh/sshd_config | awk '{print $2}' | head -n 1)

    # 如果未找到 Port 配置，则检查 SSH 服务实际监听的端口
    if [[ -z "$ssh_port" ]]; then
        log_warn "未在 /etc/ssh/sshd_config 中找到 Port 配置，尝试检查 SSH 服务实际监听的端口..."
        if command -v ss &> /dev/null; then
            ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | awk -F: '{print $NF}' | head -n 1)
        elif command -v netstat &> /dev/null; then
            ssh_port=$(netstat -tlnp | grep sshd | awk '{print $4}' | awk -F: '{print $NF}' | head -n 1)
        else
            log_warn "未找到 ss 或 netstat 命令，无法检查 SSH 服务实际监听的端口。"
        fi
    fi

    # 如果仍然未找到端口，则使用默认端口 22
    if [[ -z "$ssh_port" ]]; then
        log_warn "无法确定 SSH 端口，使用默认端口 22。"
        ssh_port=22
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

    # 添加重启 fail2ban 服务的提示
    log_info "为了让规则生效，正在重启 fail2ban 服务..."
    systemctl restart fail2ban
    if systemctl is-active --quiet fail2ban; then
        log_info "fail2ban 服务已成功重启。"
        log_info "fail2ban安装成功！"  # 新增提示
    else
        log_error "fail2ban 服务重启失败，请手动检查。"
    fi
}

# 主函数
main() {
    while true; do
        # 显示 GitHub 地址，嵌入到分割线中
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}GitHub: https://github.com/sillda76/VPSKit${NC}"
        echo -e "${BLUE}----------------------------------------${NC}"
        echo "欢迎使用 fail2ban 自动安装和配置脚本"
        echo "本脚本将执行以下操作："
        echo "- 检查系统环境和权限"
        echo "- 安装 fail2ban 和 rsyslog（仅限 Debian 12 及以上版本）"
        echo "- 配置 fail2ban，保护 SSH 服务"
        echo "- 启动并启用 fail2ban 服务"
        echo "- 显示配置状态和常用命令"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}常用命令：${NC}"
        echo "1. 查看状态: fail2ban-client status"
        echo "2. 查看 SSH 监狱状态: fail2ban-client status sshd"
        echo "3. 封禁 IP: fail2ban-client set sshd banip <IP>"
        echo "4. 解封 IP: fail2ban-client set sshd unbanip <IP>"
        echo "5. 查看日志: tail -f /var/log/fail2ban.log"
        echo "6. 查看自定义配置文件: cat /etc/fail2ban/jail.local"
        echo -e "${BLUE}========================================${NC}"
        read -p "请输入选项 (1-6) 或是否继续安装并配置 fail2ban？(y/n): " choice
        case "$choice" in
            1)
                fail2ban-client status
                ;;
            2)
                fail2ban-client status sshd
                ;;
            3)
                read -p "请输入要封禁的 IP 地址: " ip
                if [[ -n "$ip" ]]; then
                    fail2ban-client set sshd banip "$ip"
                    log_info "已封禁 IP: $ip"
                else
                    log_error "未输入 IP 地址，操作取消。"
                fi
                ;;
            4)
                read -p "请输入要解封的 IP 地址: " ip
                if [[ -n "$ip" ]]; then
                    fail2ban-client set sshd unbanip "$ip"
                    log_info "已解封 IP: $ip"
                else
                    log_error "未输入 IP 地址，操作取消。"
                fi
                ;;
            5)
                tail -f /var/log/fail2ban.log
                ;;
            6)
                cat /etc/fail2ban/jail.local
                ;;
            y|Y)
                log_info "用户选择继续安装，开始执行脚本..."
                break  # 跳出循环，继续执行安装逻辑
                ;;
            n|N)
                log_info "用户选择退出，脚本终止。"
                exit 0
                ;;
            *)
                log_error "无效的输入，请输入 1-6、y 或 n。"
                ;;
        esac
    done

    # 原有逻辑
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
