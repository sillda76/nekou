#!/bin/bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m' # 亮绿色
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 恢复默认颜色

# 全局变量：记录规则编号
ipv4_rule_number=""
ipv6_rule_number=""

# 获取本机公网 IP
get_public_ip() {
    echo -e "${BLUE}===== 本机公网 IP =====${NC}"
    ipv4=$(curl -s https://ifconfig.me/ip)
    ipv6=$(curl -s https://ifconfig.me/ip --ipv6)
    
    if [ -n "$ipv4" ]; then
        echo -e "${CYAN}IPv4: ${GREEN}$ipv4${NC}"
    else
        echo -e "${CYAN}IPv4: ${RED}No IPv4${NC}"
    fi

    if [ -n "$ipv6" ]; then
        echo -e "${CYAN}IPv6: ${GREEN}$ipv6${NC}"
    else
        echo -e "${CYAN}IPv6: ${RED}No IPv6${NC}"
    fi
    echo -e "${BLUE}======================${NC}"
}

# 检查 iptables 是否已安装
check_iptables_installed() {
    if command -v iptables &> /dev/null; then
        echo -e "${CYAN}iptables: ${GREEN}已安装${NC}"
        return 0
    else
        echo -e "${CYAN}iptables: ${RED}未安装${NC}"
        return 1
    fi
}

# 检查 ip6tables 是否已安装
check_ip6tables_installed() {
    if command -v ip6tables &> /dev/null; then
        echo -e "${CYAN}ip6tables: ${GREEN}已安装${NC}"
        return 0
    else
        echo -e "${CYAN}ip6tables: ${RED}未安装${NC}"
        return 1
    fi
}

# 检查 IPv4 禁 Ping 状态
check_ipv4_ping_status() {
    if iptables -L INPUT -v -n | grep -q "icmp.*DROP"; then
        echo -e "${LIGHT_GREEN}已启用${NC}"
    else
        echo -e "${RED}未启用${NC}"
    fi
}

# 检查 IPv6 禁 Ping 状态
check_ipv6_ping_status() {
    if ip6tables -L INPUT -v -n | grep -q "icmpv6.*DROP"; then
        echo -e "${LIGHT_GREEN}已启用${NC}"
    else
        echo -e "${RED}未启用${NC}"
    fi
}

# 获取 IPv4 禁 Ping 规则编号
get_ipv4_rule_number() {
    ipv4_rule_number=$(iptables -L INPUT --line-numbers | grep "icmp.*DROP" | awk '{print $1}')
}

# 获取 IPv6 禁 Ping 规则编号
get_ipv6_rule_number() {
    ipv6_rule_number=$(ip6tables -L INPUT --line-numbers | grep "icmpv6.*DROP" | awk '{print $1}')
}

# 启用 IPv4 禁 Ping
enable_ipv4_ping_block() {
    # 添加规则并获取规则编号
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    get_ipv4_rule_number
    echo -e "${GREEN}IPv4 禁 Ping 已启用。规则编号: $ipv4_rule_number${NC}"
}

# 禁用 IPv4 禁 Ping
disable_ipv4_ping_block() {
    get_ipv4_rule_number
    if [ -n "$ipv4_rule_number" ]; then
        iptables -D INPUT $ipv4_rule_number
        echo -e "${YELLOW}IPv4 禁 Ping 已禁用。规则编号: $ipv4_rule_number${NC}"
        ipv4_rule_number=""
    else
        echo -e "${RED}未找到 IPv4 禁 Ping 规则编号，无法禁用。${NC}"
    fi
}

# 启用 IPv6 禁 Ping
enable_ipv6_ping_block() {
    # 添加规则并获取规则编号
    ip6tables -A INPUT -p icmpv6 --icmpv6-type echo-request -j DROP
    get_ipv6_rule_number
    echo -e "${GREEN}IPv6 禁 Ping 已启用。规则编号: $ipv6_rule_number${NC}"
}

# 禁用 IPv6 禁 Ping
disable_ipv6_ping_block() {
    get_ipv6_rule_number
    if [ -n "$ipv6_rule_number" ]; then
        ip6tables -D INPUT $ipv6_rule_number
        echo -e "${YELLOW}IPv6 禁 Ping 已禁用。规则编号: $ipv6_rule_number${NC}"
        ipv6_rule_number=""
    else
        echo -e "${RED}未找到 IPv6 禁 Ping 规则编号，无法禁用。${NC}"
    fi
}

# 切换 IPv4 禁 Ping 状态
toggle_ipv4_ping_block() {
    if iptables -L INPUT -v -n | grep -q "icmp.*DROP"; then
        disable_ipv4_ping_block
    else
        enable_ipv4_ping_block
    fi
}

# 切换 IPv6 禁 Ping 状态
toggle_ipv6_ping_block() {
    if ip6tables -L INPUT -v -n | grep -q "icmpv6.*DROP"; then
        disable_ipv6_ping_block
    else
        enable_ipv6_ping_block
    fi
}

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}===== iptables 配置菜单 =====${NC}"
    get_public_ip
    check_iptables_installed
    check_ip6tables_installed
    echo -e "${BLUE}--------------------------------${NC}"

    # 显示 IPv4 选项（如果检测到 IPv4）
    if [ -n "$ipv4" ]; then
        echo -e "${MAGENTA}1. IPv4 禁 Ping 状态${NC} (当前状态: $(check_ipv4_ping_status))"
        if [ -n "$ipv4_rule_number" ]; then
            echo -e "   规则编号: ${GREEN}$ipv4_rule_number${NC}"
        fi
    fi

    # 显示 IPv6 选项（如果检测到 IPv6）
    if [ -n "$ipv6" ]; then
        echo -e "${MAGENTA}2. IPv6 禁 Ping 状态${NC} (当前状态: $(check_ipv6_ping_status))"
        if [ -n "$ipv6_rule_number" ]; then
            echo -e "   规则编号: ${GREEN}$ipv6_rule_number${NC}"
        fi
    fi

    echo -e "${MAGENTA}0. 退出${NC}"
    echo -e "${BLUE}================================${NC}"
}

# 主逻辑
main() {
    while true; do
        show_menu
        read -p "$(echo -e "${CYAN}请输入选项 (0-2): ${NC}")" choice

        case $choice in
            1)
                if [ -n "$ipv4" ] && check_iptables_installed &> /dev/null; then
                    toggle_ipv4_ping_block
                    # 切换状态后立即刷新菜单
                    show_menu
                else
                    echo -e "${RED}IPv4 不可用或 iptables 未安装，无法操作。${NC}"
                fi
                ;;
            2)
                if [ -n "$ipv6" ] && check_ip6tables_installed &> /dev/null; then
                    toggle_ipv6_ping_block
                    # 切换状态后立即刷新菜单
                    show_menu
                else
                    echo -e "${RED}IPv6 不可用或 ip6tables 未安装，无法操作。${NC}"
                fi
                ;;
            0)
                echo -e "${BLUE}退出脚本。${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}错误：无效的选项，请输入 0-2 之间的数字。${NC}"
                ;;
        esac
        echo ""
        read -n 1 -s -r -p "$(echo -e "${YELLOW}按任意键返回菜单...${NC}")"
    done
}

# 执行主逻辑
main
