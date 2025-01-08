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

# 4. 配置 Fail2ban 来保护 SSH
SSH_PORT=$(sshd -T | grep "port " | awk '{print $2}')
echo "配置 Fail2ban 来保护 SSH 端口 $SSH_PORT..."

# 创建自定义的 Fail2ban 配置文件
FAIL2BAN_SSH_CONFIG="/etc/fail2ban/jail.d/sshd.local"
echo "[sshd]" | sudo tee $FAIL2BAN_SSH_CONFIG
echo "enabled = true" | sudo tee -a $FAIL2BAN_SSH_CONFIG
echo "port = $SSH_PORT" | sudo tee -a $FAIL2BAN_SSH_CONFIG
echo "filter = sshd" | sudo tee -a $FAIL2BAN_SSH_CONFIG
echo "logpath = /var/log/auth.log" | sudo tee -a $FAIL2BAN_SSH_CONFIG
echo "maxretry = 5" | sudo tee -a $FAIL2BAN_SSH_CONFIG
echo "findtime = 600" | sudo tee -a $FAIL2BAN_SSH_CONFIG
echo "bantime = 3600" | sudo tee -a $FAIL2BAN_SSH_CONFIG
echo "action = %(action_mwl)s" | sudo tee -a $FAIL2BAN_SSH_CONFIG

# 5. 重启 Fail2ban 服务以应用更改
echo "重启 Fail2ban 服务..."
sudo systemctl restart fail2ban

# 6. 设置 Fail2ban 开机自启动
echo "设置 Fail2ban 开机自启动..."
sudo systemctl enable fail2ban

# 7. 查看 Fail2ban 服务状态
echo "查看 Fail2ban 服务状态..."
sudo systemctl status fail2ban

echo "Fail2ban 安装和配置完成！"
