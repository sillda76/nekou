#!/bin/bash

# 1. 安装 Fail2ban
echo "正在安装 Fail2ban..."
sudo apt update
sudo apt-get install -y fail2ban

# 2. 检测是否需要安装 rsyslog
DEBIAN_VERSION=$(lsb_release -rs)
if [[ "$DEBIAN_VERSION" =~ ^1[2-9] ]]; then
    echo "检测到 Debian 12 及以上系统，正在安装 rsyslog..."
    sudo apt-get install -y rsyslog

    # 3. 设置监听当前 SSH 端口
    SSH_PORT=$(sshd -T | grep "port " | awk '{print $2}')
    echo "当前 SSH 端口为: $SSH_PORT"

    echo "配置 rsyslog 监听 SSH 端口..."
    echo "\$ModLoad imtcp" | sudo tee -a /etc/rsyslog.conf
    echo "\$InputTCPServerRun $SSH_PORT" | sudo tee -a /etc/rsyslog.conf

    # 重启 rsyslog 服务以应用更改
    sudo systemctl restart rsyslog
    echo "rsyslog 已配置为监听 SSH 端口 $SSH_PORT"
fi

# 4. 启动 Fail2ban 服务
echo "启动 Fail2ban 服务..."
sudo systemctl start fail2ban

# 5. 设置 Fail2ban 开机自启动
echo "设置 Fail2ban 开机自启动..."
sudo systemctl enable fail2ban

# 6. 查看 Fail2ban 服务状态
echo "查看 Fail2ban 服务状态..."
sudo systemctl status fail2ban

echo "Fail2ban 安装和配置完成！"
