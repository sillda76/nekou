#!/bin/bash

# 打印脚本标题（仅在准备运行时显示）
echo "============================================"
echo "           SSH 配置与 Fail2Ban 安装脚本       "
echo "============================================"
echo "本脚本将执行以下操作："
echo "1. 修改 SSH 密码为 Qq667766。"
echo "2. 修改 SSH 端口为 3222。"
echo "3. 安装并配置 Fail2Ban，保护 SSH 服务。"
echo "============================================"

# 询问是否修改 SSH 密码和端口
read -p "是否修改 SSH 密码和端口？(y/n): " modify_ssh
if [ "$modify_ssh" != "y" ] && [ "$modify_ssh" != "Y" ]; then
    echo "用户选择不修改 SSH 配置，退出脚本。"
    exit 0
fi

# 修改 SSH 密码为 Qq667766
echo "正在修改 SSH 密码为 Qq667766..."
echo "root:Qq667766" | sudo chpasswd
if [ $? -eq 0 ]; then
    echo "SSH 密码修改成功！"
else
    echo "SSH 密码修改失败，请检查权限。"
    exit 1
fi

# 设置新端口
NEW_PORT=3222

# 检查配置文件是否存在
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ ! -f "$SSHD_CONFIG" ]; then
    echo "错误：未找到 SSH 配置文件 $SSHD_CONFIG。"
    exit 1
fi

# 获取当前 SSH 端口
CURRENT_PORT=$(grep "^Port" "$SSHD_CONFIG" | awk '{print $2}')
if [ -z "$CURRENT_PORT" ]; then
    CURRENT_PORT=22  # 默认端口
fi
echo "当前 SSH 端口: $CURRENT_PORT"

# 修改 SSH 端口
echo "正在修改 SSH 端口为 $NEW_PORT..."
sudo sed -i "s/^#Port 22/Port $NEW_PORT/" "$SSHD_CONFIG"
if grep -q "^Port $NEW_PORT" "$SSHD_CONFIG"; then
    echo "SSH 端口修改成功！"
else
    echo "错误：SSH 端口修改失败。"
    exit 1
fi

# 重启 SSH 服务
echo "正在重启 SSH 服务..."
sudo systemctl restart sshd
if [ $? -eq 0 ]; then
    echo "SSH 服务重启成功！"
else
    echo "错误：SSH 服务重启失败。"
    exit 1
fi

# 检查端口是否被占用
echo "检查端口 $NEW_PORT 是否被占用..."
if sudo netstat -tuln | grep -q ":$NEW_PORT"; then
    echo "警告：端口 $NEW_PORT 已被占用，请选择其他端口。"
    exit 1
else
    echo "端口 $NEW_PORT 可用。"
fi

# 检测并放行防火墙端口
echo "检测防火墙并放行端口 $NEW_PORT..."
if command -v ufw &> /dev/null; then
    echo "检测到 ufw 防火墙，正在放行端口 $NEW_PORT..."
    sudo ufw allow "$NEW_PORT/tcp"
    sudo ufw reload
    echo "端口 $NEW_PORT 已放行。"
elif command -v firewall-cmd &> /dev/null; then
    echo "检测到 firewalld 防火墙，正在放行端口 $NEW_PORT..."
    sudo firewall-cmd --permanent --add-port="$NEW_PORT/tcp"
    sudo firewall-cmd --reload
    echo "端口 $NEW_PORT 已放行。"
else
    echo "未检测到支持的防火墙工具（ufw 或 firewalld），请手动放行端口 $NEW_PORT。"
fi

# 提示用户记住新的端口和密码
echo "重要提示："
echo "1. SSH 端口已修改为 $NEW_PORT。"
echo "2. SSH 密码已修改为 Qq667766。"
echo "请务必记住以上信息，否则可能导致无法登录服务器！"

# 询问是否安装 fail2ban
read -p "是否安装 Fail2Ban？(y/n): " install_fail2ban
if [ "$install_fail2ban" != "y" ] && [ "$install_fail2ban" != "Y" ]; then
    echo "用户选择不安装 Fail2Ban，退出脚本。"
    exit 0
fi

# 安装 fail2ban
echo "正在安装 Fail2Ban..."
sudo apt-get update
sudo apt-get install -y fail2ban

# 检测是否为 Debian 12 系统
if grep -q "Debian GNU/Linux 12" /etc/os-release; then
    echo "检测到 Debian 12 系统，正在安装 rsyslog..."
    sudo apt-get install -y rsyslog
fi

# 启动并启用 fail2ban 服务
echo "正在启动并启用 Fail2Ban 服务..."
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# 设置 fail2ban 监听 3222 端口
echo "正在设置 Fail2Ban 监听 3222 端口..."
sudo sed -i 's/port    = ssh/port    = 3222/' /etc/fail2ban/jail.local
sudo systemctl restart fail2ban

# 提示用户是否查看 fail2ban 状态
read -p "是否查看 Fail2Ban 状态？(y/n): " view_status
if [ "$view_status" = "y" ] || [ "$view_status" = "Y" ]; then
    echo "Fail2Ban 当前状态："
    sudo systemctl status fail2ban
fi

echo "脚本执行完成！"
exit 0
