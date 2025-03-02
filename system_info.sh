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
    sudo apt install net-tools curl -y || { echo -e "${RED}安装依赖失败！${NC}"; exit 1; }
}

# 获取公网 IP，ASN 和运营商信息
get_ip_info() {
    # 使用 ipinfo 查询 API 获取 IP 和 ASN 信息
    local token="3b01046f048430"
    local ipv4=$(curl -s --max-time 3 "https://ipinfo.io/ip?token=$token")
    local ipv6=$(curl -s --max-time 3 "https://ipinfo.io/ip6?token=$token")

    if [[ -n "$ipv4" ]]; then
        # 获取 IPv4 的 ASN 和运营商信息
        local ipv4_details=$(curl -s "https://ipinfo.io/$ipv4/json?token=$token")
        local ipv4_asn=$(echo "$ipv4_details" | jq -r '.org' | awk '{print $1}')
        local ipv4_provider=$(echo "$ipv4_details" | jq -r '.org' | sed 's/AS[0-9]* //')

        echo -e "${GREEN}IPv4:${NC} $ipv4"
        echo -e "${ORANGE}ASN:${NC} $ipv4_asn"
        echo -e "${ORANGE}运营商:${NC} $ipv4_provider"
    fi

    if [[ -n "$ipv6" && "$ipv6" != "$ipv4" ]]; then
        # 获取 IPv6 的 ASN 和运营商信息
        local ipv6_details=$(curl -s "https://ipinfo.io/$ipv6/json?token=$token")
        local ipv6_asn=$(echo "$ipv6_details" | jq -r '.org' | awk '{print $1}')
        local ipv6_provider=$(echo "$ipv6_details" | jq -r '.org' | sed 's/AS[0-9]* //')

        echo -e "${GREEN}IPv6:${NC} $ipv6"
        echo -e "${ORANGE}ASN:${NC} $ipv6_asn"
        echo -e "${ORANGE}运营商:${NC} $ipv6_provider"
    fi

    if [[ -z "$ipv4" && -z "$ipv6" ]]; then
        echo -e "${RED}No Public IP${NC}"
    fi
}

# 切换显示的 IP 地址和 ASN 运营商
toggle_ip_info() {
    local choice
    echo -e "${YELLOW}选择显示哪个IP地址的 ASN 和运营商：${NC}"
    echo -e "${ORANGE}1. 显示 IPv4 的 ASN 和运营商${NC}"
    echo -e "${ORANGE}2. 显示 IPv6 的 ASN 和运营商${NC}"
    read -p "请输入选项 (1 或 2): " choice

    case $choice in
        1)
            get_ip_info
            ;;
        2)
            get_ip_info
            ;;
        *)
            echo -e "${RED}无效选项，请选择 1 或 2${NC}"
            ;;
    esac
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

    if [[ -f /etc/motd.bak ]]; then
        echo -e "${YELLOW}还原 /etc/motd 文件...${NC}"
        sudo mv /etc/motd.bak /etc/motd
    elif [[ -f /etc/motd ]]; then
        echo -e "${YELLOW}清空 /etc/motd 文件...${NC}"
        sudo truncate -s 0 /etc/motd
    fi

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
ORANGE='\033[1;38;5;208m'
BLUE='\033[1;34m'
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

get_ip_info() {
    ipv4=\$(curl -s --max-time 3 "https://ipinfo.io/ip?token=3b01046f048430")
    ipv6=\$(curl -s --max-time 3 "https://ipinfo.io/ip6?token=3b01046f048430")

    if [[ -n "\$ipv4" ]]; then
        echo -e "\${GREEN}IPv4:\${NC} \$ipv4"
        ipv4_details=\$(curl -s "https://ipinfo.io/\$ipv4/json?token=3b01046f048430")
        ipv4_asn=\$(echo "\$ipv4_details" | jq -r '.org' | awk '{print $1}')
        ipv4_provider=\$(echo "\$ipv4_details" | jq -r '.org' | sed 's/AS[0-9]* //')
        echo -e "\${ORANGE}ASN:\${NC} \$ipv4_asn"
        echo -e "\${ORANGE}运营商:\${NC} \$ipv4_provider"
    fi

    if [[ -n "\$ipv6" && "\$ipv6" != "\$ipv4" ]]; then
        echo -e "\${GREEN}IPv6:\${NC} \$ipv6"
        ipv6_details=\$(curl -s "https://ipinfo.io/\$ipv6/json?token=3b01046f048430")
        ipv6_asn=\$(echo "\$ipv6_details" | jq -r '.org' | awk '{print $1}')
        ipv6_provider=\$(echo "\$ipv6_details" | jq -r '.org' | sed 's/AS[0-9]* //')
        echo -e "\${ORANGE}ASN:\${NC} \$ipv6_asn"
        echo -e "\${ORANGE}运营商:\${NC} \$ipv6_provider"
    fi
}

# 主菜单
show_menu() {
    while true; do
        clear
        echo -e "${ORANGE}=========================${NC}"
        echo -e "${ORANGE}请选择操作：${NC}"
        echo -e "${ORANGE}1. 安装 SSH 欢迎系统信息${NC}"
        echo -e "${ORANGE}2. 卸载脚本及系统信息${NC}"
        echo -e "${ORANGE}3. 切换 IPv4 或 IPv6 的 ASN 和运营商显示${NC}"
        echo -e "${ORANGE}0. 退出脚本${NC}"
        echo -e "${ORANGE}当前状态：$(check_installed)${NC}"
        echo -e "${ORANGE}=========================${NC}"
        read -p "请输入选项 (0、1、2 或 3): " choice

        case $choice in
            1)
                install
                ;;
            2)
                uninstall
                read -n 1 -s -r -p "按任意键返回菜单..."
                ;;
            3)
                toggle_ip_info
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
