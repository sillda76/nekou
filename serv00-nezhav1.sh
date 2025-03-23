#!/bin/bash

# 下载最新 FreeBSD 版本的 agent 函数
download_latest_agent() {
    echo "正在获取最新的 FreeBSD 版本下载链接..."
    download_url=$(curl -s https://api.github.com/repos/nezhahq/agent/releases/latest | grep browser_download_url | grep freebsd_amd64.zip | cut -d '"' -f 4)
    if [ -z "$download_url" ]; then
        echo "未能获取最新下载链接，请检查网络连接或手动下载."
        exit 1
    fi
    echo "最新版本下载链接：$download_url"
    echo "开始下载最新的 FreeBSD 版本..."
    wget "$download_url" -O nezha-agent_freebsd_amd64.zip
    if [ $? -ne 0 ]; then
        echo "下载失败，请检查网络或下载链接."
        exit 1
    fi
    unzip nezha-agent_freebsd_amd64.zip
    # 假设解压后生成的文件名为 nezha-agent，将其重命名为 nezhav1
    mv nezha-agent nezhav1
    chmod 755 nezhav1
    rm -rf nezha-agent_freebsd_amd64.zip
}

# 安装 nezha 的逻辑函数（选项2）
install_nezha() {
    cd ~/domains
    mkdir -p nezhav1
    cd nezhav1

    config_file="config.yml"
    # 如果检测到 config.yml 存在，则列出内容并提示用户是否重新下载安装并重新配置
    if [ -f "$config_file" ]; then
        echo "检测到已有 $config_file 文件，内容如下："
        cat "$config_file"
        read -p "是否重新下载安装并重新配置? (y/n): " reinstall_choice
        if [ "$reinstall_choice" != "y" ]; then
            echo "取消重新下载安装。"
            return
        fi
    fi

    # 下载最新 agent（无论是否存在旧的 nezhav1 文件，都进行下载）
    download_latest_agent

    # 生成或重新生成 config.yml 文件
    read -p "请输入 client_secret: " client_secret
    read -p "请输入 server 地址 (例如: misaka.es:8008): " server
    read -p "是否启用 TLS (y/n): " tls_input
    tls=$( [ "$tls_input" == "y" ] && echo "true" || echo "false" )
    read -p "是否手动输入 UUID? (y/n): " uuid_choice
    if [ "$uuid_choice" = "y" ]; then
        read -p "请输入 UUID: " uuid
    else
        uuid=$(uuidgen)
    fi

    echo "client_secret: $client_secret
debug: false
disable_auto_update: false
disable_command_execute: false
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

    # 询问是否开启进程保活
    read -p "是否开启进程保活? (y/n): " enable_process_guard
    if [ "$enable_process_guard" = "y" ] || [ "$enable_process_guard" = "Y" ]; then
        echo '{ "item": [ "nezha-agent" ], "chktime": "420", "sendtype": null }' > check_process.json
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

    # 清理可能存在的旧进程后启动 nezha
    kill $(pgrep nezhav1) >/dev/null 2>&1
    sleep 2
    nohup ./nezhav1 -c config.yml >/dev/null 2>&1 &
    echo "It is ok"
}

# 更新 agent 的逻辑函数（选项4）
update_agent() {
    cd ~/domains/nezhav1
    # 清理 nezha 进程
    pkill -f "nezhav1" >/dev/null 2>&1
    pkill -f "check_process.sh" >/dev/null 2>&1
    echo "进程清理完成"
    # 删除旧的 agent 文件
    rm -f nezhav1
    echo "旧的 agent 已删除，开始更新..."
    download_latest_agent
    if [ ! -f config.yml ]; then
        echo "config.yml 文件不存在，请先运行安装流程进行配置."
        exit 1
    fi
    # 启动 agent
    kill $(pgrep nezhav1) >/dev/null 2>&1
    sleep 2
    nohup ./nezhav1 -c config.yml >/dev/null 2>&1 &
    echo "agent 更新并重启完成"
    # 重新启动进程保活（如果已配置）
    if [ -f check_process.json ]; then
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
        echo "进程保活已重新开启，检查间隔为7分钟"
    fi
}

# 显示菜单
echo "请选择操作:"
echo "1. 停止 nezha 并清理进程以及磁盘"
echo "2. 开始安装 nezha"
echo "3. 重启 nezha"
echo "4. 更新 agent"
read -p "请输入选项 (1/2/3/4): " option

case "$option" in
    1)
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
        exit 0
        ;;
    2)
        install_nezha
        ;;
    3)
        # 重启 nezha：仅清理 nezha 进程，然后重新启动
        pkill -f "nezhav1" >/dev/null 2>&1
        pkill -f "check_process.sh" >/dev/null 2>&1
        echo "进程清理完成"
        cd ~/domains/nezhav1
        nohup ./nezhav1 -c config.yml >/dev/null 2>&1 &
        echo "nezha 已重启"
        ;;
    4)
        update_agent
        ;;
    *)
        echo "无效选项，请选择 1、2、3 或 4"
        exit 1
        ;;
esac
