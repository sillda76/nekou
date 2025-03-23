#!/bin/bash

read -p "是否清理进程和磁盘，恢复系统初始状态？y/n: " choice

if [ "$choice" = "y" ]; then
    # 清理进程
    pkill -f "nezhav1" >/dev/null 2>&1
    pkill -f "check_process.sh" >/dev/null 2>&1
    echo "进程清理完成"

    # 清理磁盘
    rm -rf ~/domains/nezhav1/* >/dev/null 2>&1
    rm -rf ~/.cache/* >/dev/null 2>&1
    rm -rf ~/.local/share/Trash/* >/dev/null 2>&1
    rm -rf ~/.npm/* >/dev/null 2>&1
    rm -rf ~/.yarn/* >/dev/null 2>&1
    rm -rf ~/Downloads/* >/dev/null 2>&1
    rm -rf ~/downloads/* >/dev/null 2>&1
    rm -rf ~/tmp/* >/dev/null 2>&1
    rm -rf ~/logs/* >/dev/null 2>&1
    : > ~/.bash_history
    echo "磁盘清理完成"
fi

cd ~/domains
mkdir -p nezhav1
cd nezhav1
if [ -f nezhav1 ]; then
    echo "nezhav1 已存在，跳过下载。"
else
    wget https://github.com/nezhahq/agent/releases/download/v1.7.3/nezha-agent_freebsd_amd64.zip
    unzip nezha-agent_freebsd_amd64.zip
    mv nezha-agent nezhav1
    chmod 755 nezhav1
fi

config_file="config.yml"
# 检查 config.yml 文件是否已存在
if [ -f "$config_file" ]; then
    echo "$config_file 已存在。"
else
    # 提示用户输入 client_secret 和 server
    read -p "请输入 client_secret: " client_secret
    read -p "请输入 server 地址 (例如: github.com/IP:8008): " server
    # 提示用户设置 tls
    read -p "是否启用 TLS (y/n): " tls_input
    tls=$( [ "$tls_input" == "y" ] && echo "true" || echo "false" )
    # 生成随机的 UUID
    uuid=$(uuidgen)
    # 通过 echo 将内容写入 config.yml
    echo "client_secret: $client_secret
debug: false
disable_auto_update: false
disable_command_execute: true
disable_force_update: false
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: $server
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: $tls
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $uuid" > "$config_file"
    echo "$config_file 文件已生成，UUID: $uuid"
fi

# 询问是否开启进程保活
read -p "是否开启进程保活? (y/n): " enable_process_guard
if [ "$enable_process_guard" = "y" ] || [ "$enable_process_guard" = "Y" ]; then
    # 创建进程保活配置文件
    echo '{ "item": [ "nezha-agent" ], "chktime": "420", "sendtype": null }' > check_process.json

    # 创建进程检查脚本
    cat > check_process.sh << 'EOF'
#!/bin/bash
while true; do
    if ! pgrep -f "nezhav1" > /dev/null; then
        cd $(dirname $0)
        nohup ./nezhav1 -c config.yml >/dev/null 2>&1 &
        echo "Process restarted at $(date)"
    fi
    sleep 420
done
EOF

    chmod +x check_process.sh
    nohup ./check_process.sh >/dev/null 2>&1 &
    echo "进程保活已开启，检查间隔为7分钟"
fi

rm -rf nezha-agent_freebsd_amd64.zip
kill $(pgrep nezhav1)
sleep 2
nohup ./nezhav1 -c config.yml >/dev/null 2>&1 &
echo "It is ok"
