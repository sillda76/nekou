#!/bin/bash

# 检查当前是否禁用了Ping (IPv4)
check_ipv4_ping() {
    iptables -L INPUT -v -n | grep -q "icmp type 8"
    if [ $? -eq 0 ]; then
        echo "已禁用 IPv4 Ping"
        return 1
    else
        echo "未禁用 IPv4 Ping"
        return 0
    fi
}

# 检查当前是否禁用了Ping (IPv6)
check_ipv6_ping() {
    ip6tables -L INPUT -v -n | grep -q "icmpv6 type 128"
    if [ $? -eq 0 ]; then
        echo "已禁用 IPv6 Ping"
        return 1
    else
        echo "未禁用 IPv6 Ping"
        return 0
    fi
}

# 禁用或启用IPv4 Ping
toggle_ipv4_ping() {
    check_ipv4_ping
    if [ $? -eq 0 ]; then
        echo "禁用 IPv4 Ping..."
        iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
        echo "IPv4 Ping 已禁用"
    else
        echo "启用 IPv4 Ping..."
        iptables -D INPUT -p icmp --icmp-type echo-request -j DROP
        echo "IPv4 Ping 已启用"
    fi
    save_rules
}

# 禁用或启用IPv6 Ping
toggle_ipv6_ping() {
    check_ipv6_ping
    if [ $? -eq 0 ]; then
        echo "禁用 IPv6 Ping..."
        ip6tables -A INPUT -p icmpv6 --icmpv6-type echo-request -j DROP
        echo "IPv6 Ping 已禁用"
    else
        echo "启用 IPv6 Ping..."
        ip6tables -D INPUT -p icmpv6 --icmpv6-type echo-request -j DROP
        echo "IPv6 Ping 已启用"
    fi
    save_rules
}

# 保存规则以确保重启后生效
save_rules() {
    echo "正在保存规则为永久规则..."
    if ! command -v iptables-save &>/dev/null; then
        echo "iptables-save 未安装，请安装后重试！"
        exit 1
    fi

    # 保存 IPv4 和 IPv6 规则
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6

    # 确保规则在重启时加载
    if ! grep -q "iptables-restore < /etc/iptables/rules.v4" /etc/network/interfaces 2>/dev/null; then
        echo "pre-up iptables-restore < /etc/iptables/rules.v4" >> /etc/network/interfaces
    fi
    if ! grep -q "ip6tables-restore < /etc/iptables/rules.v6" /etc/network/interfaces 2>/dev/null; then
        echo "pre-up ip6tables-restore < /etc/iptables/rules.v6" >> /etc/network/interfaces
    fi

    echo "规则保存成功，并将在重启后自动加载。"
}

# 主菜单
while true; do
    clear
    echo "======== 禁用或启用 Ping 设置 ========"
    echo "当前状态："
    check_ipv4_ping
    check_ipv6_ping
    echo "====================================="
    echo "请选择一个选项："
    echo "1) 开启/关闭 IPv4 禁 Ping"
    echo "2) 开启/关闭 IPv6 禁 Ping"
    echo "3) 保存当前规则为永久规则"
    echo "4) 退出"
    echo "====================================="
    read -p "请输入选项 (1/2/3/4): " choice

    case $choice in
    1)
        toggle_ipv4_ping
        read -p "按任意键返回菜单..."
        ;;
    2)
        toggle_ipv6_ping
        read -p "按任意键返回菜单..."
        ;;
    3)
        save_rules
        read -p "按任意键返回菜单..."
        ;;
    4)
        echo "退出脚本..."
        exit 0
        ;;
    *)
        echo "无效选项，请重试..."
        sleep 2
        ;;
    esac
done
