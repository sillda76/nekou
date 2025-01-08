#!/bin/bash

# 定义颜色变量
ORANGE='\033[0;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# 1. 安装 Fail2ban
echo -e "${GREEN}正在安装 Fail2ban...${NC}"
sudo apt update
sudo apt-get install -y fail2ban

# 2. 检测是否需要安装 rsyslog
OS_NAME=$(lsb_release -is)
OS_VERSION=$(lsb_release -rs)
if [[ "$OS_NAME" == "Debian" && "$OS_VERSION" =~ ^1[2-9] ]] || [[ "$OS_NAME" == "Ubuntu" ]]; then
    echo -e "${ORANGE}检测到 Debian 12 及以上系统或 Ubuntu，正在安装 rsyslog...${NC}"
    sudo apt-get install -y rsyslog

    # 3. 设置监听当前 SSH 端口
    SSH_PORT=$(sshd -T | grep "port " | awk '{print $2}')
    echo -e "${BLUE}当前 SSH 端口为: ${NC}$SSH_PORT"

    echo -e "${ORANGE}配置 rsyslog 监听 SSH 端口...${NC}"
    echo "\$ModLoad imtcp" | sudo tee -a /etc/rsyslog.conf
    echo "\$InputTCPServerRun $SSH_PORT" | sudo tee -a /etc/rsyslog.conf

    # 重启 rsyslog 服务以应用更改
    sudo systemctl restart rsyslog
    echo -e "${GREEN}rsyslog 已配置为监听 SSH 端口 $SSH_PORT${NC}"
fi

# 4. 配置 Fail2ban 来保护 SSH
SSH_PORT=$(sshd -T | grep "port " | awk '{print $2}')
echo -e "${ORANGE}配置 Fail2ban 来保护 SSH 端口 $SSH_PORT...${NC}"

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
echo -e "${ORANGE}重启 Fail2ban 服务...${NC}"
sudo systemctl restart fail2ban

# 6. 设置 Fail2ban 开机自启动
echo -e "${ORANGE}设置 Fail2ban 开机自启动...${NC}"
sudo systemctl enable fail2ban

# 7. 查看 Fail2ban 服务状态
echo -e "${ORANGE}查看 Fail2ban 服务状态...${NC}"
sudo systemctl status fail2ban

echo -e "${GREEN}Fail2ban 安装和配置完成！${NC}"
