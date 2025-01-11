#!/bin/bash

install() {
    # 创建目录
    mkdir -p ~/.local

    # 安装必要工具
    sudo apt install bc net-tools curl -y

    # 备份原始SSH欢迎信息
    if [[ -f /etc/motd ]]; then
        sudo cp /etc/motd /etc/motd.bak
        sudo truncate -s 0 /etc/motd
    fi

    # 生成系统信息脚本
    cat << EOF > ~/.local/sysinfo.sh
#!/bin/bash

# ANSI colors
RED='\033[1;31m'
GREEN='\033[1;32m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
ORANGE='\033[1;33m'
NC='\033[0m'

# Function to create a progress bar
progress_bar() {
    local progress=\$1
    local total=\$2
    local bar_width=20
    local filled=\$(echo "(\$progress/\$total)*\$bar_width" | bc -l | awk '{printf "%d", \$1}')
    local empty=\$((bar_width - filled))

    printf "["
    for ((i=0; i<filled; i++)); do printf "\${PURPLE}=\${NC}"; done
    for ((i=0; i<empty; i++)); do printf "\${GREEN}=\${NC}"; done
    printf "]"
}

# OS information
os_info=\$(cat /etc/os-release | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')

# Uptime
uptime_info=\$(uptime -p | sed 's/up //g')

# CPU information
cpu_info=\$(lscpu | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | xargs)
cpu_cores=\$(lscpu | grep "^CPU(s):" | awk '{print \$2}')
cpu_speed=\$(lscpu | grep "CPU MHz" | awk '{print \$3/1000 "GHz"}' | xargs)

# 格式化 CPU 信息
if [ -n "\$cpu_speed" ]; then
    cpu_output="\${cpu_cores} cores (\${cpu_info}) @\$cpu_speed"
else
    cpu_output="\${cpu_cores} cores (\${cpu_info})"
fi

# Memory usage
memory_total=\$(free -m | grep Mem: | awk '{print \$2}')
memory_used=\$(free -m | grep Mem: | awk '{print \$3}')
memory_usage=\$(awk "BEGIN {printf \\"%.0fMB / %.0fMB (%.0f%%)\\", \$memory_used, \$memory_total, (\$memory_used/\$memory_total)*100}")

# Swap usage
swap_total=\$(free -m | grep Swap: | awk '{print \$2}')
swap_used=\$(free -m | grep Swap: | awk '{print \$3}')
swap_usage=\$(awk "BEGIN {printf \\"%.0fMB / %.0fMB (%.0f%%)\\", \$swap_used, \$swap_total, (\$swap_used/\$swap_total)*100}")

# Disk usage for root filesystem
disk_total=\$(df -k / | grep / | awk '{print \$2}')
disk_used=\$(df -k / | grep / | awk '{print \$3}')
disk_usage=\$(df -h / | grep / | awk '{print \$3 " / " \$2 " (" \$5 ")"}')

# 获取运营商和地理位置信息
get_ipinfo() {
    local ip=\$1
    ipinfo_data=\$(curl -s "https://ipinfo.io/\$ip/json")
    if [[ -n "\$ipinfo_data" ]]; then
        isp=\$(echo "\$ipinfo_data" | grep '"org":' | sed 's/.*"org": "\(.*\)",/\1/')
        city=\$(echo "\$ipinfo_data" | grep '"city":' | sed 's/.*"city": "\(.*\)",/\1/')
        region=\$(echo "\$ipinfo_data" | grep '"region":' | sed 's/.*"region": "\(.*\)",/\1/')
        country=\$(echo "\$ipinfo_data" | grep '"country":' | sed 's/.*"country": "\(.*\)",/\1/')
        if [[ -n "\$city" && -n "\$region" && -n "\$country" ]]; then
            location="\$city, \$region, \$country"
        else
            location="Unknown Location"
        fi
        echo "\${GREEN}ISP:\${NC} \$isp"
        echo "\${GREEN}Location:\${NC} \$location"
    else
        echo "\${GREEN}ISP:\${NC} Unknown ISP"
        echo "\${GREEN}Location:\${NC} Unknown Location"
    fi
}

# 获取 IPv4 和 IPv6 的信息
get_public_ip() {
    ipv4=\$(curl -s ipv4.icanhazip.com 2>/dev/null)
    ipv6=\$(curl -s ipv6.icanhazip.com 2>/dev/null)

    if [[ -n "\$ipv4" ]]; then
        echo "\${GREEN}IPv4:\${NC} \$ipv4"
        get_ipinfo "\$ipv4"
    elif [[ -n "\$ipv6" ]]; then
        echo "\${GREEN}IPv6:\${NC} \$ipv6"
        get_ipinfo "\$ipv6"
    else
        echo "\${RED}No Public IP\${NC}"
    fi
}

# 获取网络流量信息
get_network_traffic() {
    rx_bytes=\$(cat /proc/net/dev | grep 'eth0:' | awk '{print \$2}')
    tx_bytes=\$(cat /proc/net/dev | grep 'eth0:' | awk '{print \$10}')
    rx_gb=\$(awk "BEGIN {printf \"%.2f\", \$rx_bytes/1024/1024/1024}")
    tx_gb=\$(awk "BEGIN {printf \"%.2f\", \$tx_bytes/1024/1024/1024}")
    echo "\${RED}↑:\${NC}\$tx_gb GB    \${GREEN}↓:\${NC}\$rx_gb GB"
}

# Display the information
echo -e "\${ORANGE}OS:\${NC}        \$os_info"
echo -e "\${ORANGE}Uptime:\${NC}    \$uptime_info"
echo -e "\${ORANGE}CPU:\${NC}       \$cpu_output"

if [[ \$swap_total -ne 0 ]]; then
    echo -ne "\${ORANGE}Memory:\${NC}    "
    progress_bar \$memory_used \$memory_total
    echo " \$memory_usage"
    echo -e "\${ORANGE}Swap:\${NC}      \$swap_usage"
else
    echo -ne "\${ORANGE}Memory:\${NC}    "
    progress_bar \$memory_used \$memory_total
    echo " \$memory_usage"
fi

echo -ne "\${ORANGE}Disk:\${NC}      "
progress_bar \$disk_used \$disk_total
echo " \$disk_usage"
echo -e "\${ORANGE}Traffic:\${NC}   \$(get_network_traffic)"
get_public_ip
EOF

    # 设置脚本可执行权限
    chmod +x ~/.local/sysinfo.sh

    # 修改.bashrc以在SSH登录时显示系统信息
    if ! grep -q 'if $\[ \$- == \*i\* && -n "\$SSH_CONNECTION" $\]; then' ~/.bashrc; then
        echo '# SYSINFO SSH LOGIC START' >> ~/.bashrc
        echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    # 重新加载.bashrc
    source ~/.bashrc >/dev/null 2>&1

    echo -e "\033[32m系统信息工具安装完成！\033[0m"
}

uninstall() {
    # 删除系统信息脚本
    rm -f ~/.local/sysinfo.sh

    # 从.bashrc中移除相关配置
    sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc

    # 恢复原始SSH欢迎信息
    if [[ -f /etc/motd.bak ]]; then
        sudo mv /etc/motd.bak /etc/motd
    else
        sudo truncate -s 0 /etc/motd
    fi

    echo -e "\033[32m系统信息工具已卸载！\033[0m"
}

# 主逻辑
if [[ "$1" == "-u" ]]; then
    uninstall
else
    install
fi
