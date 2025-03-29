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

# 函数：获取优先级状态描述
get_precedence_status() {
    if grep -q '^precedence ::ffff:0:0/96  100' /etc/gai.conf 2>/dev/null; then
        echo "IPv4"
    elif grep -q '^precedence ::/0           20' /etc/gai.conf 2>/dev/null; then
        echo "IPv6"
    else
        echo "默认"
    fi
}

# 函数：测试IP优先级（简化版）
test_ip_precedence() {
    echo "使用DNS解析顺序测试IP优先级..."
    echo "测试命令：getent ahosts youtube.com"
    echo "--------------------------------------"
    
    # 直接显示原始结果
    getent ahosts youtube.com 2>/dev/null || echo -e "\033[31m错误：无法解析测试域名\033[0m"
}

# 函数：配置IP协议优先级
config_ip_precedence() {
    while true; do
        clear
        current_status=$(get_precedence_status)
        
        echo "======================================"
        echo " IP协议优先级配置"
        echo "======================================"
        echo " 当前优先级: ${current_status}"
        echo "--------------------------------------"
        echo "1. 优先使用IPv4"
        echo "2. 优先使用IPv6"
        echo "3. 恢复默认优先级"
        echo "4. 测试当前优先级"
        echo "0. 返回主菜单"
        
        read -p "请选择操作 [0-4]: " choice
        case $choice in
            1)
                sed -i '/^precedence/d' /etc/gai.conf
                echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
                echo "已设置优先使用IPv4"
                test_ip_precedence
                read -p "按回车键返回菜单..."
                ;;
            2)
                sed -i '/^precedence/d' /etc/gai.conf
                echo "precedence ::/0           20" >> /etc/gai.conf
                echo "precedence ::1/128       50" >> /etc/gai.conf
                echo "已设置优先使用IPv6"
                test_ip_precedence
                read -p "按回车键返回菜单..."
                ;;
            3)
                sed -i '/^precedence/d' /etc/gai.conf
                echo "已恢复默认优先级配置"
                test_ip_precedence
                read -p "按回车键返回菜单..."
                ;;
            4)
                test_ip_precedence
                read -p "按回车键返回菜单..."
                ;;
            0)
                return
                ;;
            *)
                echo "无效选择！"
                ;;
        esac
    done
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
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
    
    if ! grep -q 'ipv6.disable=1' /etc/default/grub; then
        sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ ipv6.disable=1"/' /etc/default/grub
    fi
    update-grub
    
    sysctl -p >/dev/null
    echo "已永久禁用IPv6"
    restart_network
}

# 函数：恢复IPv6设置
restore_ipv6() {
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sed -i 's/ ipv6.disable=1//g' /etc/default/grub
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
        
        v4_status=$(sysctl -n net.ipv4.icmp_echo_ignore_all 2>/dev/null)
        v6_status=$(sysctl -n net.ipv6.icmp.echo_ignore_all 2>/dev/null || echo 0)
        
        echo "1. IPv4禁Ping当前状态: $(show_status $v4_status)"
        echo "2. IPv6禁Ping当前状态: $(show_status $v6_status)"
        echo "0. 返回主菜单"
        
        read -p "请选择操作 [0-2]: " choice
        
        case $choice in
            1)
                new_status=$((1 - v4_status))
                sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
                echo "net.ipv4.icmp_echo_ignore_all=$new_status" >> /etc/sysctl.conf
                sysctl -p >/dev/null
                echo -e "\n\033[32mIPv4禁Ping已$([ $new_status -eq 1 ] && echo '开启' || echo '关闭')\033[0m"
                ;;
            2)
                new_status=$((1 - v6_status))
                sed -i '/net.ipv6.icmp.echo_ignore_all/d' /etc/sysctl.conf
                echo "net.ipv6.icmp.echo_ignore_all=$new_status" >> /etc/sysctl.conf
                sysctl -p >/dev/null
                echo -e "\n\033[32mIPv6禁Ping已$([ $new_status -eq 1 ] && echo '开启' || echo '关闭')\033[0m"
                ;;
            0)
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
    echo "1. 配置IP协议优先级（当前：$(get_precedence_status)）"
    echo "2. 临时禁用IPv6（重启后恢复）"
    echo "3. 永久禁用IPv6" 
    echo "4. 恢复IPv6默认设置"
    echo "5. 配置禁Ping设置"
    echo "0. 退出"
    echo "======================================"
    
    read -p "请选择操作 [0-5]: " option
    case $option in
        1) config_ip_precedence ;;
        2)
            read -p "确定要临时禁用IPv6吗？(y/N): " confirm
            [[ $confirm =~ [Yy] ]] && temp_disable_ipv6
            ;;
        3)
            read -p "永久禁用IPv6需要重启系统，确定继续吗？(y/N): " confirm
            [[ $confirm =~ [Yy] ]] && perm_disable_ipv6
            ;;
        4)
            read -p "确定要恢复IPv6默认设置吗？(y/N): " confirm
            [[ $confirm =~ [Yy] ]] && restore_ipv6
            ;;
        5) config_ping_block ;;
        0) exit 0 ;;
        *) echo "无效选项，请重新输入！" ;;
    esac
    
    read -p "按回车键返回主菜单..."
done
