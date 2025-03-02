#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
NC='\033[0m'

# Token for ipinfo.io（请确保此Token有效，否则需要替换）
TOKEN="3b01046f048430"

# 检查是否已安装
check_installed() {
    if [[ -f ~/.local/sysinfo.sh ]] && grep -q '# SYSINFO SSH LOGIC START' ~/.bashrc; then
        echo -e "${GREEN}已安装${NC}"
        return 0
    else
        echo -e "${RED}未安装${NC}"
        return 1
    fi
}

# 进度条函数
progress_bar() {
    local progress=$1
    local total=$2
    local bar_width=20
    local filled=$((progress * bar_width / total))
    local empty=$((bar_width - filled))

    printf "["
    for ((i=0; i<filled; i++)); do
        if ((i < filled / 3)); then
            printf "${GREEN}=${NC}"
        elif ((i < 2 * filled / 3)); then
            printf "${YELLOW}=${NC}"
        else
            printf "${RED}=${NC}"
        fi
    done
    for ((i=0; i<empty; i++)); do
        printf "${BLACK}=${NC}"
    done
    printf "]"
}

# 安装依赖工具
install_dependencies() {
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}未找到 bc 工具，正在安装...${NC}"
        sudo apt install bc -y || { echo -e "${RED}安装 bc 失败！${NC}"; exit 1; }
    fi
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}未找到 curl 工具，正在安装...${NC}"
        sudo apt install curl -y || { echo -e "${RED}安装 curl 失败！${NC}"; exit 1; }
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}未找到 jq 工具，正在安装...${NC}"
        sudo apt install jq -y || { echo -e "${RED}安装 jq 失败！${NC}"; exit 1; }
    fi
    sudo apt install net-tools -y || { echo -e "${RED}安装 net-tools 失败！${NC}"; exit 1; }
}

# 获取公网IP、ASN和ISP信息
get_public_ip() {
    # 尝试获取IPv4
    ipv4=$(curl -s --max-time 3 "https://ipinfo.io/ip?token=$TOKEN")
    if [[ -z "$ipv4" ]]; then
        echo -e "${RED}无法获取 IPv4 地址，请检查网络连接或Token有效性${NC}"
    else
        echo -e "${GREEN}IPv4:${NC} $ipv4"
        ipv4_info=$(curl -s --max-time 3 "https://ipinfo.io/$ipv4?token=$TOKEN")
        if [[ -n "$ipv4_info" ]]; then
            asn=$(echo "$ipv4_info" | jq -r '.asn.asn // "N/A"')
            isp=$(echo "$ipv4_info" | jq -r '.asn.name // "N/A"')
            if [[ "$asn" != "N/A" && "$isp" != "N/A" ]]; then
                echo -e "${CYAN}$asn $isp${NC}"
            else
                echo -e "${RED}无法获取 IPv4 的 ASN 和 ISP 信息，请检查Token或网络${NC}"
            fi
        else
            echo -e "${RED}无法获取 IPv4 详细信息，请检查网络或Token${NC}"
        fi
    fi

    # 尝试获取IPv6
    ipv6=$(curl -s --max-time 3 "https://ipinfo.io/ip?token=$TOKEN" -6)
    if [[ -z "$ipv6" ]]; then
        echo -e "${RED}无法获取 IPv6 地址（可能不支持IPv6）${NC}"
    else
        echo -e "${GREEN}IPv6:${NC} $ipv6"
        ipv6_info=$(curl -s --max-time 3 "https://ipinfo.io/$ipv6?token=$TOKEN")
        if [[ -n "$ipv6_info" ]]; then
            asn=$(echo "$ipv6_info" | jq -r '.asn.asn // "N/A"')
            isp=$(echo "$ipv6_info" | jq -r '.asn.name // "N/A"')
            if [[ "$asn" != "N/A" && "$isp" != "N/A" ]]; then
                echo -e "${CYAN}$asn $isp${NC}"
            else
                echo -e "${RED}无法获取 IPv6 的 ASN 和 ISP 信息，请检查Token或网络${NC}"
            fi
        else
            echo -e "${RED}无法获取 IPv6 详细信息，请检查网络或Token${NC}"
        fi
    fi

    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}无法获取任何公网IP，请检查网络连接${NC}"
    fi
}

# 卸载函数
uninstall() {
    echo -e "${YELLOW}正在卸载系统信息工具...${NC}"
    if [[ -f ~/.local/sysinfo.sh ]]; then
        echo -e "${YELLOW}删除系统信息脚本...${NC}"
        rm -f ~/.local/sysinfo.sh
    fi
    if grep -q '# SYSINFO SSH LOGIC START' ~/.bashrc; then
        echo -e "${YELLOW}清理 ~/.bashrc 配置...${NC}"
        sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc
    fi
    if grep -q '# 命令行美化' ~/.bashrc; then
        echo -e "${YELLOW}清理命令行美化配置...${NC}"
        sed -i '/# 命令行美化/,/# 命令行美化结束/d' ~/.bashrc
    fi
    if [[ -f /etc/motd.bak ]]; then
        echo -e "${YELLOW}还原 /etc/motd 文件...${NC}"
        sudo mv /etc/motd.bak /etc/motd
    elif [[ -f /etc/motd ]]; then
        echo -e "${YELLOW}清空 /etc/motd 文件...${NC}"
        sudo truncate -s 0 /etc/motd
    fi
    echo -e "${GREEN}系统信息工具已卸载！${NC}"
}

# 安装函数
install() {
    if check_installed; then
        echo -e "${YELLOW}系统信息工具已安装，是否覆盖安装？${NC}"
        read -p "覆盖安装将卸载并重新安装，是否继续？[y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${YELLOW}已取消安装。${NC}"
            return
        else
            echo -e "${YELLOW}正在卸载旧版本...${NC}"
            uninstall
        fi
    fi

    mkdir -p ~/.local
    echo -e "${YELLOW}正在安装依赖工具...${NC}"
    install_dependencies

    if [[ -f /etc/motd ]]; then
        echo -e "${YELLOW}备份 /etc/motd 文件到 /etc/motd.bak...${NC}"
        sudo cp /etc/motd /etc/motd.bak
        sudo truncate -s 0 /etc/motd
        echo -e "${GREEN}备份完成，备份文件路径：/etc/motd.bak${NC}"
    fi

    echo -e "${YELLOW}正在创建系统信息脚本...${NC}"
    cat << EOF > ~/.local/sysinfo.sh
#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
NC='\033[0m'

TOKEN="$TOKEN"

progress_bar() {
    local progress=\$1
    local total=\$2
    local bar_width=20
    local filled=\$((progress * bar_width / total))
    local empty=\$((bar_width - filled))

    printf "["
    for ((i=0; i<filled; i++)); do
        if ((i < filled / 3)); then
            printf "\${GREEN}=\${NC}"
        elif ((i < 2 * filled / 3)); then
            printf "\${YELLOW}=\${NC}"
        else
            printf "\${RED}=\${NC}"
        fi
    done
    for ((i=0; i<empty; i++)); do
        printf "\${BLACK}=\${NC}"
    done
    printf "]"
}

os_info=\$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')
uptime_seconds=\$(cat /proc/uptime | awk '{print \$1}')
uptime_days=\$(bc <<< "scale=0; \$uptime_seconds / 86400")
uptime_hours=\$(bc <<< "scale=0; (\$uptime_seconds % 86400) / 3600")
uptime_minutes=\$(bc <<< "scale=0; (\$uptime_seconds % 3600) / 60")
uptime_info="\${uptime_days} days, \${uptime_hours} hours, \${uptime_minutes} minutes"
cpu_info=\$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | sed 's/CPU @.*//g' | xargs)
cpu_cores=\$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print \$2}')
load_info=\$(cat /proc/loadavg | awk '{print \$1", "\$2", "\$3}')
memory_total=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$2}')
memory_used=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$3}')
swap_total=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$2}')
swap_used=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$3}')
disk_total=\$(df -k / 2>/dev/null | grep / | awk '{print \$2}')
disk_used=\$(df -k / 2>/dev/null | grep / | awk '{print \$3}')

get_network_traffic() {
    local interface=\$(ip route | grep default | awk '{print \$5}' | head -n 1)
    if [[ -z "\$interface" ]]; then
        interface="eth0"
    fi
    local rx_bytes=\$(cat /sys/class/net/\$interface/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx_bytes=\$(cat /sys/class/net/\$interface/statistics/tx_bytes 2>/dev/null || echo 0)

    format_bytes() {
        local bytes=\$1
        if (( bytes >= 1099511627776 )); then
            echo "\$(awk "BEGIN {printf \"%.2f TB\", \$bytes / 1099511627776}")"
        elif (( bytes >= 1073741824 )); then
            echo "\$(awk "BEGIN {printf \"%.2f GB\", \$bytes / 1073741824}")"
        else
            echo "\$(awk "BEGIN {printf \"%.2f MB\", \$bytes / 1048576}")"
        fi
    }

    local rx_traffic=\$(format_bytes \$rx_bytes)
    local tx_traffic=\$(format_bytes \$tx_bytes)
    echo -e "\${ORANGE}Traffic:\${NC} \${BLUE}TX:\${NC} \${YELLOW}\$tx_traffic\${NC}, \${BLUE}RX:\${NC} \${GREEN}\$rx_traffic\${NC}"
}

echo -e "\${ORANGE}OS:\${NC}        \${os_info:-N/A}"
echo -e "\${ORANGE}Uptime:\${NC}    \${uptime_info:-N/A}"
echo -e "\${ORANGE}CPU:\${NC}       \${cpu_info:-N/A} (\${cpu_cores:-N/A} cores)"
echo -e "\${ORANGE}Load:\${NC}      \${load_info:-N/A}"
echo -ne "\${ORANGE}Memory:\${NC}    "
progress_bar \$memory_used \$memory_total
echo " \${memory_used:-N/A}MB / \${memory_total:-N/A}MB (\$(awk "BEGIN {printf \"%.0f%%\", (\$memory_used/\$memory_total)*100}"))"
if [[ -n "\$swap_total" && \$swap_total -ne 0 ]]; then
    swap_usage=\$(awk "BEGIN {printf \"%.0fMB / %.0fMB (%.0f%%)\", \$swap_used, \$swap_total, (\$swap_used/\$swap_total)*100}")
    echo -e "\${ORANGE}Swap:\${NC}      \$swap_usage"
fi
echo -ne "\${ORANGE}Disk:\${NC}      "
progress_bar \$disk_used \$disk_total
echo " \$(df -h / 2>/dev/null | grep / | awk '{print \$3 " / " \$2 " (" \$5 ")'}')"
get_network_traffic

# 获取公网IP、ASN和ISP信息
get_public_ip() {
    ipv4=\$(curl -s --max-time 3 "https://ipinfo.io/ip?token=$TOKEN")
    if [[ -z "\$ipv4" ]]; then
        echo -e "\${RED}无法获取 IPv4 地址，请检查网络连接或Token有效性\${NC}"
    else
        echo -e "\${GREEN}IPv4:\${NC} \$ipv4"
        ipv4_info=\$(curl -s --max-time 3 "https://ipinfo.io/\$ipv4?token=$TOKEN")
        if [[ -n "\$ipv4_info" ]]; then
            asn=\$(echo "\$ipv4_info" | jq -r '.asn.asn // "N/A"')
            isp=\$(echo "\$ipv4_info" | jq -r '.asn.name // "N/A"')
            if [[ "\$asn" != "N/A" && "\$isp" != "N/A" ]]; then
                echo -e "\${CYAN}\$asn \$isp\${NC}"
            else
                echo -e "\${RED}无法获取 IPv4 的 ASN 和 ISP 信息，请检查Token或网络\${NC}"
            fi
        else
            echo -e "\${RED}无法获取 IPv4 详细信息，请检查网络或Token\${NC}"
        fi
    fi

    ipv6=\$(curl -s --max-time 3 "https://ipinfo.io/ip?token=$TOKEN" -6)
    if [[ -z "\$ipv6" ]]; then
        echo -e "\${RED}无法获取 IPv6 地址（可能不支持IPv6）\${NC}"
    else
        echo -e "\${GREEN}IPv6:\${NC} \$ipv6"
        ipv6_info=\$(curl -s --max-time 3 "https://ipinfo.io/\$ipv6?token=$TOKEN")
        if [[ -n "\$ipv6_info" ]]; then
            asn=\$(echo "\$ipv6_info" | jq -r '.asn.asn // "N/A"')
            isp=\$(echo "\$ipv6_info" | jq -r '.asn.name // "N/A"')
            if [[ "\$asn" != "N/A" && "\$isp" != "N/A" ]]; then
                echo -e "\${CYAN}\$asn \$isp\${NC}"
            else
                echo -e "\${RED}无法获取 IPv6 的 ASN 和 ISP 信息，请检查Token或网络\${NC}"
            fi
        else
            echo -e "\${RED}无法获取 IPv6 详细信息，请检查网络或Token\${NC}"
        fi
    fi

    if [[ -z "\$ipv4" && -z "\$ipv6" ]]; then
        echo -e "\${RED}无法获取任何公网IP，请检查网络连接\${NC}"
    fi
}

get_public_ip
EOF

    chmod +x ~/.local/sysinfo.sh

    if ! grep -q 'if [[ \$- == *i* && -n "\$SSH_CONNECTION" ]]; then' ~/.bashrc; then
        echo '# SYSINFO SSH LOGIC START' >> ~/.bashrc
        echo 'if [[ \$- == *i* && -n "\$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    if ! grep -q '# 命令行美化' ~/.bashrc; then
        echo '# 命令行美化' >> ~/.bashrc
        echo 'parse_git_branch() {' >> ~/.bashrc
        echo '    git branch 2> /dev/null | sed -e '\''/^[^*]/d'\'' -e '\''s/* \(.*\)/ (\1)/'\''' >> ~/.bashrc
        echo '}' >> ~/.bashrc
        echo 'PS1='\''\[\033[01;38;5;117m\]\u\[\033[01;33m\]@\[\033[01;33m\]\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[01;35m\]$(parse_git_branch)\[\033[00m\] \[\033[01;36m\][\D{%H:%M:%S}]\[\033[00m\]\n\[\033[01;37m\]\$ \[\033[00m\]'\''' >> ~/.bashrc
        echo '# 命令行美化结束' >> ~/.bashrc
    fi

    source ~/.bashrc >/dev/null 2>&1
    echo -e "${GREEN}系统信息工具安装完成！${NC}"
    echo -e "${GREEN}命令行美化完成！${NC}"
    echo -e "${YELLOW}系统信息脚本路径：~/.local/sysinfo.sh${NC}"
}

# 显示菜单
show_menu() {
    while true; do
        clear
        echo -e "${ORANGE}=========================${NC}"
        echo -e "${ORANGE}请选择操作：${NC}"
        echo -e "${ORANGE}1. 安装 SSH 欢迎系统信息${NC}"
        echo -e "${ORANGE}2. 卸载脚本及系统信息${NC}"
        echo -e "${ORANGE}0. 退出脚本${NC}"
        echo -e "${ORANGE}当前状态：$(check_installed)${NC}"
        echo -e "${ORANGE}=========================${NC}"
        read -p "请输入选项 (0、1 或 2): " choice

        case $choice in
            1)
                install
                ;;
            2)
                uninstall
                ;;
            0)
                echo -e "${ORANGE}退出脚本。${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}错误：无效选项，请重新输入。${NC}"
                sleep 1
                ;;
        esac
    done
}

# 主逻辑
show_menu
