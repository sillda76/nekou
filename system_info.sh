#!/bin/bash

install() {
    mkdir -p ~/.local

    sudo apt install bc net-tools curl -y

    if [[ -f /etc/motd ]]; then
        sudo cp /etc/motd /etc/motd.bak
        sudo truncate -s 0 /etc/motd
    fi

    cat << EOF > ~/.local/sysinfo.sh
#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
ORANGE='\033[1;33m'
NC='\033[0m'

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

os_info=\$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | sed 's/PRETTY_NAME="//g' | sed 's/"//g')
if [[ -z "\$os_info" ]]; then
    os_info="N/A"
fi

uptime_info=\$(uptime -p 2>/dev/null | sed 's/up //g')
if [[ -z "\$uptime_info" ]]; then
    uptime_info="N/A"
fi

cpu_info=\$(lscpu 2>/dev/null | grep -m 1 "Model name:" | sed 's/Model name:[ \t]*//g' | xargs)
cpu_cores=\$(lscpu 2>/dev/null | grep "^CPU(s):" | awk '{print \$2}')
cpu_speed=\$(lscpu 2>/dev/null | grep "CPU MHz" | awk '{print \$3/1000 "GHz"}' | xargs)

if [[ -n "\$cpu_info" && -n "\$cpu_cores" ]]; then
    if [ -n "\$cpu_speed" ]; then
        cpu_output="\$cpu_info @\$cpu_speed (\${cpu_cores} cores)"
    else
        cpu_output="\$cpu_info (\${cpu_cores} cores)"
    fi
else
    cpu_output="N/A"
fi

memory_total=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$2}')
memory_used=\$(free -m 2>/dev/null | grep Mem: | awk '{print \$3}')
if [[ -n "\$memory_total" && -n "\$memory_used" ]]; then
    memory_usage=\$(awk "BEGIN {printf \\"%.0fMB / %.0fMB (%.0f%%)\\", \$memory_used, \$memory_total, (\$memory_used/\$memory_total)*100}")
else
    memory_usage="N/A"
fi

swap_total=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$2}')
swap_used=\$(free -m 2>/dev/null | grep Swap: | awk '{print \$3}')
if [[ -n "\$swap_total" && \$swap_total -ne 0 ]]; then
    swap_usage=\$(awk "BEGIN {printf \\"%.0fMB / %.0fMB (%.0f%%)\\", \$swap_used, \$swap_total, (\$swap_used/\$swap_total)*100}")
else
    swap_usage="N/A"
fi

disk_total=\$(df -k / 2>/dev/null | grep / | awk '{print \$2}')
disk_used=\$(df -k / 2>/dev/null | grep / | awk '{print \$3}')
if [[ -n "\$disk_total" && -n "\$disk_used" ]]; then
    disk_usage=\$(df -h / 2>/dev/null | grep / | awk '{print \$3 " / " \$2 " (" \$5 ")"}')
else
    disk_usage="N/A"
fi

get_ipinfo() {
    local ip=\$1
    ipinfo_data=\$(curl -s --max-time 5 "https://ipinfo.io/\$ip/json" 2>/dev/null)
    if [[ -n "\$ipinfo_data" ]]; then
        isp=\$(echo "\$ipinfo_data" | grep '"org":' | sed 's/.*"org": *"\([^"]*\)".*/\1/')
        city=\$(echo "\$ipinfo_data" | grep '"city":' | sed 's/.*"city": *"\([^"]*\)".*/\1/')
        region=\$(echo "\$ipinfo_data" | grep '"region":' | sed 's/.*"region": *"\([^"]*\)".*/\1/')
        country=\$(echo "\$ipinfo_data" | grep '"country":' | sed 's/.*"country": *"\([^"]*\)".*/\1/')
        if [[ -n "\$city" && -n "\$region" && -n "\$country" ]]; then
            location="\$city, \$region, \$country"
        else
            location="N/A"
        fi
        echo -e "\${GREEN}Provider:\${NC} \${isp:-N/A}"
        echo -e "\${GREEN}Location:\${NC} \${location:-N/A}"
    else
        echo -e "\${GREEN}Provider:\${NC} N/A"
        echo -e "\${GREEN}Location:\${NC} N/A"
    fi
}

get_public_ip() {
    ipv4=\$(curl -s --max-time 5 ipv4.icanhazip.com 2>/dev/null)
    ipv6=\$(curl -s --max-time 5 ipv6.icanhazip.com 2>/dev/null)

    if [[ -n "\$ipv4" ]]; then
        echo -e "\${GREEN}IPv4:\${NC} \$ipv4"
        target_ip="\$ipv4"
    fi

    if [[ -n "\$ipv6" ]]; then
        echo -e "\${GREEN}IPv6:\${NC} \$ipv6"
        if [[ -z "\$target_ip" ]]; then
            target_ip="\$ipv6"
        fi
    fi

    if [[ -n "\$target_ip" ]]; then
        get_ipinfo "\$target_ip"
    else
        echo -e "\${RED}No Public IP\${NC}"
    fi
}

get_network_traffic() {
    interface=\$(ip route get 8.8.8.8 2>/dev/null | awk '{print \$5}')
    if [[ -z "\$interface" ]]; then
        echo -e "\${RED}↑:\${NC} N/A    \${GREEN}↓:\${NC} N/A"
        return
    fi

    rx_bytes=\$(cat /proc/net/dev 2>/dev/null | grep "\$interface:" | awk '{print \$2}')
    tx_bytes=\$(cat /proc/net/dev 2>/dev/null | grep "\$interface:" | awk '{print \$10}')
    if [[ -n "\$rx_bytes" && -n "\$tx_bytes" ]]; then
        rx_mb=\$(awk "BEGIN {printf \"%.2f\", \$rx_bytes/1024/1024}")
        tx_mb=\$(awk "BEGIN {printf \"%.2f\", \$tx_bytes/1024/1024}")

        if (( \$(echo "\$rx_mb >= 1024" | bc -l) )); then
            rx_gb=\$(awk "BEGIN {printf \"%.2f\", \$rx_mb/1024}")
            rx_output="\$rx_gb GB"
        else
            rx_output="\$rx_mb MB"
        fi

        if (( \$(echo "\$tx_mb >= 1024" | bc -l) )); then
            tx_gb=\$(awk "BEGIN {printf \"%.2f\", \$tx_mb/1024}")
            tx_output="\$tx_gb GB"
        else
            tx_output="\$tx_mb MB"
        fi

        echo -e "\${RED}↑:\${NC} \$tx_output    \${GREEN}↓:\${NC} \$rx_output"
    else
        echo -e "\${RED}↑:\${NC} N/A    \${GREEN}↓:\${NC} N/A"
    fi
}

echo -e "\${ORANGE}OS:\${NC}        \$os_info"
echo -e "\${ORANGE}Uptime:\${NC}    \$uptime_info"
echo -e "\${ORANGE}CPU:\${NC}       \$cpu_output"

if [[ "\$swap_usage" != "N/A" ]]; then
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

# 增加延迟，确保输出完整
sleep 0.05
EOF

    chmod +x ~/.local/sysinfo.sh

    if ! grep -q 'if $\[ \$- == \*i\* && -n "\$SSH_CONNECTION" $\]; then' ~/.bashrc; then
        echo '# SYSINFO SSH LOGIC START' >> ~/.bashrc
        echo 'if [[ $- == *i* && -n "$SSH_CONNECTION" ]]; then' >> ~/.bashrc
        echo '    bash ~/.local/sysinfo.sh' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        echo '# SYSINFO SSH LOGIC END' >> ~/.bashrc
    fi

    source ~/.bashrc >/dev/null 2>&1

    echo -e "\033[32m系统信息工具安装完成！\033[0m"
    echo -e "\033[33m如需卸载，请运行以下命令：\033[0m"
    echo -e "\033[33mbash <(wget -qO- https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/system_info.sh) -u\033[0m"
}

uninstall() {
    rm -f ~/.local/sysinfo.sh

    sed -i '/# SYSINFO SSH LOGIC START/,/# SYSINFO SSH LOGIC END/d' ~/.bashrc

    if [[ -f /etc/motd.bak ]]; then
        sudo mv /etc/motd.bak /etc/motd
    else
        sudo truncate -s 0 /etc/motd
    fi

    echo -e "\033[32m系统信息工具已卸载！\033[0m"
}

if [[ "$1" == "-u" ]]; then
    uninstall
else
    install
fi
