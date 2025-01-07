#!/bin/bash

# 检查环境变量是否定义
if [ -z "$DOMAIN_NAME" ]; then
    echo "错误：环境变量 DOMAIN_NAME 未定义。"
    exit 1
fi

domain_name=$DOMAIN_NAME

# 更新系统包
apt update

# 安装 Nginx 和 iperf
if ! nginx -v &>/dev/null; then
    apt install -y nginx
fi

if ! iperf -v &>/dev/null; then
    apt install -y iperf
fi

# 备份现有配置文件
if [ -f /etc/nginx/sites-available/$domain_name ]; then
    mv /etc/nginx/sites-available/$domain_name /etc/nginx/sites-available/$domain_name.bak
fi

# 创建 Nginx 配置文件
tee /etc/nginx/sites-available/$domain_name <<EOF
server {
    listen 998;
    server_name $domain_name;

    root /var/www/$domain_name;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# 创建符号链接
if [ ! -L /etc/nginx/sites-enabled/$domain_name ]; then
    ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
fi

# 测试 Nginx 配置
nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx 配置测试失败，请检查配置文件。"
    exit 1
fi

# 重启 Nginx
systemctl restart nginx

# 创建网站根目录
if [ ! -d /var/www/$domain_name ]; then
    mkdir -p /var/www/$domain_name
fi

# 生成 1GB 测试文件
if [ ! -f /var/www/$domain_name/1GB.test ]; then
    dd if=/dev/zero of=/var/www/$domain_name/1GB.test bs=1M count=1024
fi

# 启动 iperf 服务端
iperf -s -D  # 以守护进程模式运行 iperf 服务端

# 输出 iperf 服务端的 PID
iperf_pid=$(pgrep iperf)
echo "iperf 服务端的 PID 是 $iperf_pid"

# 持续运行 iperf 客户端进行上行测试
nohup bash -c '
while true; do
    iperf -c $domain_name -t 60 -i 10 > /dev/null 2>&1
    sleep 10
done
' > /dev/null 2>&1 &

# 输出持续测试的 PID
echo "持续测试的 PID 是 $!"

echo "持续上行测试已启动，无日志记录。"
