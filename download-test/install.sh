#!/bin/bash
(apt update && apt install -y lsof) > /dev/null 2>&1

service=$(lsof -i :80 | awk 'NR==2 {print $1}')

if [ ! -z "$service" ]; then
    if [ "$service" != "nginx" ]; then
        echo "80端口被$service占用，请将其暂停后再运行此脚本"
        exit 1
    fi
fi

echo "=============================================="
echo "PS!"
echo "请在脚本开始执行后检查 eth0 网卡是否在进行测试"
read -p "请输入已解析本机IP的域名或者本机IP(如果脚本开始执行流量没在跑就给域名套上CF即可): " domain_name
echo "=============================================="

echo "请选择测试选项："
echo "1. 24小时全时段持续测试"
echo "2. 随机时间测试"
read -p "请输入选择：" choice

case $choice in
    1)
        echo "正在下载 '直接24小时持续跑流量' 脚本..."
        url="https://github.com/sillda76/VPSKit/raw/refs/heads/main/download-test/24test.sh"
        script_file="script.sh"
        wget -O $script_file $url
        chmod +x $script_file
        export DOMAIN_NAME=$domain_name
        ./$script_file
        ;;
    2)
        echo "正在下载 '随机时间跑流量' 脚本..."
        url="https://github.com/sillda76/VPSkit/raw/main/random.sh"
        read -p "请输入最小等待时间（秒）: " min_wait
        read -p "请输入最大等待时间（秒）: " max_wait
        script_file="script.sh"
        wget -O $script_file $url
        chmod +x $script_file
        export DOMAIN_NAME=$domain_name
        export MIN_WAIT=$min_wait
        export MAX_WAIT=$max_wait
        nohup ./$script_file > /dev/null 2>&1 &
        echo "$script_file 的 PID 是 $!"
        ;;
    *)
        echo "无效的输入。退出安装。"
        exit 1
        ;;
esac
