#!/bin/bash

# 颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'  # 橙色
NC='\033[0m'

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
    if [[ -n "$ipv6" && "$ipv6" != *"DOCTYPE"* ]]; then
        echo -e "${GREEN}IPv6:${NC} $ipv6"
    fi
    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi
}

# 安装函数
install() {
    mkdir -p ~/.local

    install_dependencies

    if [[ -f /etc/motd ]]; then
        sudo cp /etc/motd /etc/motd.bak
        sudo truncate -s 0 /etc/motd
    fi

    cat << EOF > ~/.local/sysinfo.sh
#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLACK='\033[1;30m'
ORANGE='\033[1;38;5;208m'  # 橙色
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

os_info=\$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')
uptime_info=\$(uptime -p 2>/dev/null | sed 's/up //g')
cpu_info=\$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | sed 's/CPU @.*//g' | xargs)
cpu_cores=\$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print \$2}')
memory_total=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$2}')
memory_used=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$3}')
swap_total=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$2}')
swap_used=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$3}')
disk_total=\$(df -k / 2>/dev/null | grep / | awk '{print \$2}')
disk_used=\$(df -k / 2>/dev/null | grep / | awk '{print \$3}')

echo -e "\${ORANGE}OS:\${NC}        \${os_info:-N/A}"
echo -e "\${ORANGE}Uptime:\${NC}    \${uptime_info:-N/A}"
echo -e "\${ORANGE}CPU:\${NC}       \${cpu_info:-N/A} (\${cpu_cores:-N/A} cores)"

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

get_public_ip() {
    ipv4=\$(curl -s --max-time 3 ipv4.icanhazip.com || curl -s --max-time 3 ifconfig.me)
    ipv6=\$(curl -s --max-time 3 ipv6.icanhazip.com || curl -s --max-time 3 ifconfig.co)

    if [[ -n "\$ipv4" ]]; then
        echo -e "\${GREEN}IPv4:\${NC} \$ipv4"
    fi
    if [[ -n "\$ipv6" && "\$ipv6" != *"DOCTYPE"* ]]; then
        echo -e "\${GREEN}IPv6:\${NC} \$ipv6"
    fi
    if [[ -z "\$ipv4" && -z "\$ipv6" ]]; then
        echo -e "\${RED}No Public IP\${NC}"
    fi
}

get_public_ip
EOF

    chmod +x ~/.local/sysinfo.sh

    if ! grep -q 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' ~/.bashrc; then
        echo '# SYSINFO SSH LOGIC START' >> ~/.bashrc
        echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    source ~/.bashrc >/dev/null 2>&1
    echo -e "${GREEN}系统信息工具安装完成！${NC}"
}

# 卸载函数
uninstall() {
    rm -f ~/.local/sysinfo.sh
    sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc

    if [[ -f /etc/motd.bak ]]; then
        sudo mv /etc/motd.bak /etc/motd
    else
        sudo truncate -s 0 /etc/motd
    fi

    echo -e "${GREEN}系统信息工具已卸载！${NC}"
}

# 显示菜单
show_menu() {
    while true; do
        echo -e "${ORANGE}=========================${NC}"
        echo -e "${ORANGE}请选择操作：${NC}"
        echo -e "${ORANGE}1. 安装 SSH 欢迎系统信息${NC}"
        echo -e "${ORANGE}2. 卸载脚本及系统信息${NC}"
        echo -e "${ORANGE}0. 退出脚本${NC}"
        echo -e "${ORANGE}=========================${NC}"
        read -p "请输入选项 (0、1 或 2): " choice

        case $choice in
            1)
                install
                exit 0
                ;;
            2)
                uninstall
                exit 0
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
