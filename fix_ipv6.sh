#!/bin/bash
# 一键配置静态IPv6（适配图片中的Debian系统）
# 功能：保留现有IPv4 DHCP，仅添加静态IPv6配置

# 配置参数（直接从图片中提取）
INTERFACE="enp6s18"                  # 图片中的网卡名
IPV6_ADDRESS="2a01:4f9:1a:98f0::13"  # 您的独立IPv6地址（商家提供）
IPV6_GATEWAY="2a01:4f9:1a:98f0::3"   # 图片中提到的IPv6网关
PREFIX="64"                          # IPv6前缀长度

# 备份原网络配置
cp /etc/network/interfaces /etc/network/interfaces.bak

# 写入配置（保留IPv4 DHCP，仅添加IPv6）
cat > /etc/network/interfaces <<EOF
# IPv4 (保持原有DHCP)
auto $INTERFACE
iface $INTERFACE inet dhcp

# IPv6 (新增静态配置)
iface $INTERFACE inet6 static
    address $IPV6_ADDRESS/$PREFIX
    gateway $IPV6_GATEWAY
EOF

# 重启网络并验证
systemctl restart networking
echo "✅ IPv6配置完成！当前网络状态："
ip -6 addr show $INTERFACE | grep "inet6"
ping6 -c 3 google.com
