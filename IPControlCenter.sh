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

# 函数：重启网络服务
restart_network() {
    if systemctl is-active --quiet NetworkManager; then
        systemctl restart NetworkManager
    else
        systemctl restart networking
    fi
    echo "已重启网络服务使配置生效"
}

# 函数：配置IP协议优先级
config_ip_precedence() {
    current_precedence=$(grep '^precedence' /etc/gai.conf 2>/dev/null | awk '{print $NF}')
    
    echo "======================================"
    echo " 当前IPv6优先级: ${current_precedence:-默认}"
    echo "======================================"
    echo "1. 优先使用IPv4"
    echo "2. 优先使用IPv6"
    echo "3. 返回主菜单"
    
    read -p "请选择优先级模式 [1-3]: " choice
    case $choice in
        1)
            sed -i '/^precedence/d' /etc/gai.conf
            echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
            echo "已设置优先使用IPv4"
            ;;
        2)
            sed -i '/^precedence/d' /etc/gai.conf
            echo "precedence ::/0           20" >> /etc/gai.conf
            echo "precedence ::1/128       50" >> /etc/gai.conf
            echo "已设置优先使用IPv6"
            ;;
        3)
            return
            ;;
        *)
            echo "无效选择！"
            ;;
    esac
}

# 函数：临时禁用IPv6
temp_disable_ipv6() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
    echo "已临时禁用IPv6（重启后失效）"
    restart_network
}

# 函数：永久禁用IPv6
perm_disable_ipv6() {
    # 修改sysctl配置
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
    
    # 修改grub配置（针对Debian系）
    if grep -q 'ipv6.disable=1' /etc/default/grub; then
        sed -i 's/ipv6.disable=1//g' /etc/default/grub
    else
        sed -i 's/GRUB_CMDLINE_LINUX="/&ipv6.disable=1 /' /etc/default/grub
    fi
    update-grub
    
    sysctl -p >/dev/null
    echo "已永久禁用IPv6"
    restart_network
}

# 函数：恢复IPv6设置
restore_ipv6() {
    # 清除sysctl配置
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    
    # 清除grub配置
    sed -i 's/ipv6.disable=1//g' /etc/default/grub
    update-grub
    
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null
    sysctl -p >/dev/null
    echo "已恢复IPv6默认设置"
    restart_network
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
        
        read -p "请选择要配置的项目 [1-3]: " choice
        
        case $choice in
            1)
                if [ "$v4_status" = "1" ]; then
                    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
                    sysctl -w net.ipv4.icmp_echo_ignore_all=0 >/dev/null
                    echo -e "\n\033[32mIPv4禁Ping已关闭！\033[0m"
                else
                    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
                    echo "net.ipv4.icmp_echo_ignore_all=1" >> /etc/sysctl.conf
                    sysctl -p >/dev/null
                    echo -e "\n\033[32mIPv4禁Ping已开启！\033[0m"
                fi
                ;;
            2)
                if [ "$v6_status" = "1" ]; then
                    sed -i '/net.ipv6.icmp.echo_ignore_all/d' /etc/sysctl.conf
                    sysctl -w net.ipv6.icmp.echo_ignore_all=0 >/dev/null
                    echo -e "\n\033[32mIPv6禁Ping已关闭！\033[0m"
                else
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
        
        restart_network
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
        1) 
            config_ip_precedence 
            ;;
        2)
            read -p "确定要临时禁用IPv6吗？(y/N): " confirm
            if [[ $confirm =~ [Yy] ]]; then
                temp_disable_ipv6
            else
                echo "操作已取消"
            fi
            ;;
        3)
            read -p "永久禁用IPv6需要重启系统，确定继续吗？(y/N): " confirm
            if [[ $confirm =~ [Yy] ]]; then
                perm_disable_ipv6
            else
                echo "操作已取消"
            fi
            ;;
        4)
            read -p "确定要恢复IPv6默认设置吗？(y/N): " confirm
            if [[ $confirm =~ [Yy] ]]; then
                restore_ipv6
            else
                echo "操作已取消"
            fi
            ;;
        5) 
            config_ping_block 
            ;;
        6) 
            exit 0 
            ;;
        *) 
            echo "无效选项，请重新输入！" 
            ;;
    esac
    
    read -p "按回车键返回主菜单..."
done
