#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'  # 橙色
BLUE='\033[1;34m'  # 蓝色
NC='\033[0m'

# 检查是否已安装
check_installed() {
    local script_file=~/.local/sysinfo.sh
    local config_files=(~/.bashrc ~/.zshrc ~/.profile)
    local script_ok=0
    local config_ok=0

    # 检查脚本文件是否存在且可执行
    if [[ -f "$script_file" && -x "$script_file" ]]; then
        script_ok=1
    fi

    # 检查配置文件是否包含启动逻辑
    for shell_rc in "${config_files[@]}"; do
        if [[ -f "$shell_rc" ]] && grep -q '# SYSINFO SSH LOGIC START' "$shell_rc"; then
            config_ok=$((config_ok + 1))
        fi
    done

    # 根据检查结果返回状态
    if [[ $script_ok -eq 1 && $config_ok -eq 3 ]]; then
        echo -e "${GREEN}已安装${NC}"
        return 0
    elif [[ $script_ok -eq 1 || $config_ok -gt 0 ]]; then
        echo -e "${YELLOW}安装异常${NC}"
        return 1
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
    sudo apt install net-tools curl -y || { echo -e "${RED}安装依赖失败！${NC}"; exit 1; }
}

# 获取公网 IP
get_public_ip() {
    ipv4=$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
    ipv6=$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)

    if [[ -n "$ipv4" ]]; then
        echo -e "${GREEN}IPv4:${NC} $ipv4"
    fi
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* && "$ipv6" != "$ipv4" ]]; then
        echo -e "${GREEN}IPv6:${NC} $ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi
}

# 卸载函数
uninstall() {
    echo -e "${YELLOW}正在卸载系统信息工具...${NC}"

    # 删除系统信息脚本
    if [[ -f ~/.local/sysinfo.sh ]]; then
        echo -e "${YELLOW}删除系统信息脚本...${NC}"
        rm -f ~/.local/sysinfo.sh
    fi

    # 清理所有配置文件中的配置
    local config_files=(~/.bashrc ~/.zshrc ~/.profile)
    for shell_rc in "${config_files[@]}"; do
        if grep -q '# SYSINFO SSH LOGIC START' "$shell_rc"; then
            echo -e "${YELLOW}清理 $shell_rc 配置...${NC}"
            sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' "$shell_rc"
        fi
    done

    # 还原 /etc/motd 文件
    if [[ -f /etc/motd.bak ]]; then
        echo -e "${YELLOW}还原 /etc/motd 文件...${NC}"
        sudo mv /etc/motd.bak /etc/motd
    elif [[ -f /etc/motd ]]; then
        echo -e "${YELLOW}清空 /etc/motd 文件...${NC}"
        sudo truncate -s 0 /etc/motd
    fi

    # 删除其他临时文件或备份文件
    if [[ -f ~/.local/sysinfo_backup.tar.gz ]]; then
        echo -e "${YELLOW}删除临时备份文件...${NC}"
        rm -f ~/.local/sysinfo_backup.tar.gz
    fi

    echo -e "${GREEN}系统信息工具已卸载！${NC}"
}

# 安装函数
install() {
    if check_installed; then
        echo -e "${YELLOW}系统信息工具已安装，是否继续安装？${NC}"
        read -p "继续安装将卸载并重新安装，是否继续？[y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo -e "${YELLOW}已取消安装。${NC}"
            read -n 1 -s -r -p "按任意键返回菜单..."
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
ORANGE='\033[1;38;5;208m'  # 橙色
BLUE='\033[1;34m'  # 蓝色
NC='\033[0m'

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

# 获取系统信息
os_info=\$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')

# 将 uptime 转换为“days, hours, minutes”格式
uptime_seconds=\$(cat /proc/uptime | awk '{print \$1}')
uptime_days=\$(bc <<< "scale=0; \$uptime_seconds / 86400")
uptime_hours=\$(bc <<< "scale=0; (\$uptime_seconds % 86400) / 3600")
uptime_minutes=\$(bc <<< "scale=0; (\$uptime_seconds % 3600) / 60")
uptime_info="\${uptime_days} days, \${uptime_hours} hours, \${uptime_minutes} minutes"

cpu_info=\$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | sed 's/CPU @.*//g' | xargs)
cpu_cores=\$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print \$2}')
load_info=\$(cat /proc/loadavg | awk '{print \$1", "\$2", "\$3}')  # 获取负载信息

memory_total=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$2}')
memory_used=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$3}')
swap_total=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$2}')
swap_used=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$3}')
disk_total=\$(df -k / 2>/dev/null | grep / | awk '{print \$2}')
disk_used=\$(df -k / 2>/dev/null | grep / | awk '{print \$3}')

# 获取网络流量信息
get_network_traffic() {
    local interface=\$(ip route | grep default | awk '{print \$5}' | head -n 1)
    if [[ -z "\$interface" ]]; then
        echo "Traffic: No active interface"
        return
    fi

    local rx_bytes=\$(cat /sys/class/net/\$interface/statistics/rx_bytes)
    local tx_bytes=\$(cat /sys/class/net/\$interface/statistics/tx_bytes)

    # 转换单位为 MB、GB 或 TB
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

# 输出系统信息
echo -e "\${ORANGE}OS:\${NC}        \${os_info:-N/A}"
echo -e "\${ORANGE}Uptime:\${NC}    \${uptime_info:-N/A}"
echo -e "\${ORANGE}CPU:\${NC}       \${cpu_info:-N/A} (\${cpu_cores:-N/A} cores)"
echo -e "\${ORANGE}Load:\${NC}      \${load_info:-N/A}"  # 输出负载信息

echo -ne "\${ORANGE}Memory:\${NC}    "
progress_bar \$memory_used \$memory_total
echo " \${memory_used:-N/A}MB / \${memory_total:-N/A}MB (\$(awk "BEGIN {printf \"%.0f%%\", (\$memory_used/\$memory_total)*100}"))"

if [[ -n "\$swap_total" && \$swap_total -ne 0 ]]; then
    swap_usage=\$(awk "BEGIN {printf \"%.0fMB / %.0fMB (%.0f%%)\", \$swap_used, \$swap_total, (\$swap_used/\$swap_total)*100}")
    echo -e "\${ORANGE}Swap:\${NC}      \$swap_usage"
fi

echo -ne "\${ORANGE}Disk:\${NC}      "
progress_bar \$disk_used \$disk_total
echo " \$(df -h / 2>/dev/null | grep / | awk '{print \$3 " / " \$2 " (" \$5 ")"}')"

# 输出网络流量信息
get_network_traffic

# 获取公网 IP
get_public_ip() {
    ipv4=\$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
    ipv6=\$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)

    if [[ -n "\$ipv4" ]]; then
        echo -e "\${GREEN}IPv4:\${NC} \$ipv4"
    fi
    if [[ -n "\$ipv6" && "\$ipv6" != *"DOCTYPE"* && "\$ipv6" != "\$ipv4" ]]; then
        echo -e "\${GREEN}IPv6:\${NC} \$ipv6"
    fi
    if [[ -z "\$ipv4" && -z "\$ipv6" ]]; then
        echo -e "\${RED}No Public IP\${NC}"
    fi
}

get_public_ip
EOF

    chmod +x ~/.local/sysinfo.sh

    # 写入多个配置文件
    local config_files=(~/.bashrc ~/.zshrc ~/.profile)
    for shell_rc in "${config_files[@]}"; do
        if [[ ! -f "$shell_rc" ]]; then
            touch "$shell_rc"
        fi
        if ! grep -q '# SYSINFO SSH LOGIC START' "$shell_rc"; then
            echo '# SYSINFO SSH LOGIC START' >> "$shell_rc"
            echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> "$shell_rc"
            echo '    bash ~/.local/sysinfo.sh' >> "$shell_rc"
            echo 'fi' >> "$shell_rc"
            echo '# SYSINFO SSH LOGIC END' >> "$shell_rc"
        fi
    done

    # 重新加载配置文件
    source ~/.bashrc >/dev/null 2>&1
    source ~/.zshrc >/dev/null 2>&1
    source ~/.profile >/dev/null 2>&1

    echo -e "${GREEN}系统信息工具安装完成！${NC}"
    echo -e "${YELLOW}系统信息脚本路径：~/.local/sysinfo.sh${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 显示菜单
show_menu() {
    while true; do
        clear  # 清屏
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
                read -n 1 -s -r -p "按任意键返回菜单..."
                ;;
            0)
                echo -e "${ORANGE}退出脚本。${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"
                read -n 1 -s -r
                ;;
        esac
    done
}

# 主逻辑
show_menu
