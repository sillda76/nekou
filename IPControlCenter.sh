#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用root用户运行此脚本！"
    exit 1
fi

# 函数：显示带颜色的状态
show_status() {
    if [ "$1" = "1" ]; then
        echo -e "\033[32m[已开启]\033[0m"
    else
        echo -e "\033[31m[已关闭]\033[0m"
    fi
}

# 函数：配置禁Ping
config_ping_block() {
    while true; do
        clear
        echo "======================================"
        echo " 禁Ping配置"
        echo "======================================"
        
        # 获取当前状态
        v4_status=$(sysctl -n net.ipv4.icmp_echo_ignore_all)
        v6_status=$(sysctl -n net.ipv6.icmp.echo_ignore_all 2>/dev/null || echo "0")
        
        echo "1. IPv4禁Ping当前状态: $(show_status $v4_status)"
        echo "2. IPv6禁Ping当前状态: $(show_status $v6_status)"
        echo "3. 返回主菜单"
        echo "======================================"
        
        read -p "请选择要配置的项目 [1-3]: " choice
        
        case $choice in
            1)
                if [ "$v4_status" = "1" ]; then
                    # 关闭IPv4禁Ping
                    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
                    sysctl -w net.ipv4.icmp_echo_ignore_all=0 >/dev/null
                    echo -e "\n\033[32mIPv4禁Ping已关闭！\033[0m"
                else
                    # 开启IPv4禁Ping
                    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
                    echo "net.ipv4.icmp_echo_ignore_all=1" >> /etc/sysctl.conf
                    sysctl -p >/dev/null
                    echo -e "\n\033[32mIPv4禁Ping已开启！\033[0m"
                fi
                ;;
            2)
                if [ "$v6_status" = "1" ]; then
                    # 关闭IPv6禁Ping
                    sed -i '/net.ipv6.icmp.echo_ignore_all/d' /etc/sysctl.conf
                    sysctl -w net.ipv6.icmp.echo_ignore_all=0 >/dev/null
                    echo -e "\n\033[32mIPv6禁Ping已关闭！\033[0m"
                else
                    # 开启IPv6禁Ping
                    sed -i '/net.ipv6.icmp.echo_ignore_all/d' /etc/sysctl.conf
                    echo "net.ipv6.icmp.echo_ignore_all=1" >> /etc/sysctl.conf
                    sysctl -p >/dev/null
                    echo -e "\n\033[32mIPv6禁Ping已开启！\033[0m"
                fi
                ;;
            3)
                return
                ;;
            *)
                echo -e "\n\033[31m无效选择！\033[0m"
                ;;
        esac
        
        read -p "按回车键继续..."
    done
}

# 主菜单
while true; do
    clear
    echo "======================================"
    echo " Debian网络高级配置工具"
    echo "======================================"
    echo "1. 配置IP协议优先级"
    echo "2. 临时禁用IPv6（重启后恢复）"
    echo "3. 永久禁用IPv6" 
    echo "4. 恢复IPv6默认设置"
    echo "5. 配置禁Ping设置"
    echo "6. 退出"
    echo "======================================"
    
    read -p "请选择操作 [1-6]: " option
    case $option in
        5) 
            config_ping_block 
            ;;
        # 其他选项保持不变...
        *) 
            echo "无效选项，请重新输入！" 
            ;;
    esac
    
    read -p "按回车键返回主菜单..."
done
