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
    # 检测是否安装 iptables
    if ! command -v iptables &> /dev/null; then
        log_info "检测到未安装 iptables，正在安装 iptables..."
        apt-get install -y iptables
    else
        log_info "iptables 已安装，继续运行脚本。"
    fi

    # 检测系统版本并安装 rsyslog（仅适用于 Debian 12 及以上版本）
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

# 配置 fail2ban
configure_fail2ban() {
    log_info "正在配置 fail2ban..."

    # 备份原配置文件
    if [ -f /etc/fail2ban/jail.local ]; then
        log_warn "正在备份现有的 jail.local 文件..."
        cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d%H%M%S)
    fi

    # 检测系统日志文件路径
    if [[ -f /var/log/auth.log ]]; then
        LOGPATH="/var/log/auth.log"
    elif [[ -f /var/log/secure ]]; then
        LOGPATH="/var/log/secure"
    else
        log_error "未找到 SSH 日志文件（/var/log/auth.log 或 /var/log/secure），请检查系统日志配置。"
    fi

    # 检测 SSH 端口
    SSHD_CONFIG="/etc/ssh/sshd_config"
    if [[ -f $SSHD_CONFIG ]]; then
        SSH_PORT=$(grep -oP '^Port\s+\K\d+' $SSHD_CONFIG || echo "22")
    else
        SSH_PORT="22"
    fi

    # 创建主配置文件
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
port = ssh,$SSH_PORT
filter = sshd
logpath = $LOGPATH
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
        echo "7. 卸载 fail2ban: apt purge fail2ban"
        echo -e "${BLUE}========================================${NC}"
        read -p "请输入选项 (1-7) 或是否继续安装并配置 fail2ban？(y/n): " choice
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
            7)
                log_info "正在卸载 fail2ban..."
                apt purge -y fail2ban
                log_info "fail2ban 已卸载。"
                exit 0
                ;;
            y|Y)
                # 检测是否已安装 fail2ban
                if command -v fail2ban-client &> /dev/null; then
                    log_warn "检测到系统已安装 fail2ban。"
                    read -p "是否卸载并重新安装 fail2ban？(y/n): " reinstall_choice
                    if [[ "$reinstall_choice" == "y" || "$reinstall_choice" == "Y" ]]; then
                        log_info "正在卸载 fail2ban..."
                        apt purge -y fail2ban
                        log_info "fail2ban 已卸载，继续安装..."
                    else
                        log_info "跳过卸载，退出脚本。"
                        exit 0
                    fi
                fi

                log_info "用户选择继续安装，开始执行脚本..."
                break  # 跳出循环，继续执行安装逻辑
                ;;
            n|N)
                log_info "用户选择退出，脚本终止。"
                exit 0
                ;;
            *)
                log_error "无效的输入，请输入 1-7、y 或 n。"
                ;;
        esac

        # 提示按任意键返回交互界面
        echo -e "\n${YELLOW}按任意键返回菜单...${NC}"
        read -n 1 -s  # 捕获任意键输入，无需按 Enter
        clear  # 清除屏幕内容
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
