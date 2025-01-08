#!/bin/bash

# 更新系统包列表
sudo apt update

# 安装 fail2ban
sudo apt-get install -y fail2ban

# 启动 fail2ban 服务
sudo systemctl start fail2ban

# 配置 fail2ban 监听 22 端口，封禁时间设为一小时
sudo bash -c 'cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = 4422
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF'

# 设置 fail2ban 开机自启
sudo systemctl enable fail2ban

# 查看 fail2ban 状态
sudo systemctl status fail2ban

echo "Fail2ban 安装和配置完成！"
