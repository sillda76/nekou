#!/bin/bash
# ======================================================
# Linux 系统调优脚本
# 适用于 Debian/Ubuntu 系统，用于首次安装后进行系统优化配置
#
# 功能：
# 1. 自动更新软件源并升级系统
# 2. 自动安装 unzip、curl、wget、sudo
# 3. 交互式询问是否修改 SSH 端口（默认保持22端口）
# 4. 交互式询问是否安装 fail2ban（建议安装，直接调用远程脚本）
# 5. 交互式修改 DNS 配置，并锁定 /etc/resolv.conf 防止被重置
#    提供国外DNS优化、国内DNS优化、手动编辑和保持默认四种选项
# 6. 交互式询问是否安装 1panel（根据系统类型选择命令）
#
# 注意：请以 root 权限运行此脚本！
# ======================================================

# ---------------------------
# 主菜单函数
# ---------------------------
function main_menu() {
    clear
    echo "========================================"
    echo "         Linux 系统调优脚本"
    echo "========================================"
    echo "1. 开始系统初始化配置"
    echo "0. 退出"
    read -p "请输入选项 [0-1]: " main_choice
    case $main_choice in
        1)
            system_init
            ;;
        0)
            echo "退出脚本."
            exit 0
            ;;
        *)
            echo "错误：无效的选项！"
            read -n1 -s -r -p "按任意键返回菜单..."
            main_menu
            ;;
    esac
}

# ---------------------------
# 系统初始化配置函数
# 包含：系统更新、软件安装、SSH配置、fail2ban 安装、DNS配置、1panel 安装
# ---------------------------
function system_init() {
    clear
    echo "========================================"
    echo "[系统初始化配置] 开始"
    echo "========================================"

    # 自动更新软件源并升级
    echo "[更新] 正在更新软件源..."
    apt update && apt upgrade -y
    if [ $? -ne 0 ]; then
        echo "错误：软件源更新失败！"
        read -n1 -s -r -p "按任意键继续..."
    fi

    # 自动安装 unzip、curl、wget、sudo
    echo "[安装] 正在安装 unzip, curl, wget, sudo..."
    apt install -y unzip curl wget sudo
    if [ $? -ne 0 ]; then
        echo "错误：安装软件失败！"
        read -n1 -s -r -p "按任意键继续..."
    fi

    # 修改 SSH 端口配置
    configure_ssh

    # 安装 fail2ban
    install_fail2ban

    # DNS 配置修改并锁定
    configure_dns

    # 安装 1panel
    install_1panel

    echo "========================================"
    echo "[完成] 系统初始化配置已完成."
    read -n1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# ---------------------------
# 修改 SSH 端口配置函数
# ---------------------------
function configure_ssh() {
    echo "----------------------------------------"
    echo "[SSH配置] 是否修改 SSH 端口？默认端口为22"
    read -p "请输入 (y/n): " ssh_choice
    case $ssh_choice in
        y|Y)
            read -p "请输入新的 SSH 端口号: " new_port
            # 检查输入是否为数字
            if [[ ! $new_port =~ ^[0-9]+$ ]]; then
                echo "错误：端口号必须为数字！保持默认端口22。"
            else
                # 修改 /etc/ssh/sshd_config 文件中的 Port 设置
                # 如果存在注释的 Port 行则取消注释并修改
                sed -i "s/^#Port 22/Port $new_port/" /etc/ssh/sshd_config
                sed -i "s/^Port 22/Port $new_port/" /etc/ssh/sshd_config
                echo "[SSH配置] SSH 端口已修改为 $new_port"
                # 重启 SSH 服务（不同系统可能使用 ssh 或 sshd）
                systemctl restart ssh || systemctl restart sshd
            fi
            ;;
        n|N)
            echo "[SSH配置] 保持默认 SSH 端口22"
            ;;
        *)
            echo "错误：无效输入，保持默认端口22"
            ;;
    esac
}

# ---------------------------
# 安装 fail2ban 函数
# ---------------------------
function install_fail2ban() {
    echo "----------------------------------------"
    echo "[fail2ban安装] 是否安装 fail2ban？建议安装"
    read -p "请输入 (y/n): " f2b_choice
    case $f2b_choice in
        y|Y)
            echo "[fail2ban安装] 正在安装 fail2ban..."
            # 直接从远程脚本运行，不保存到本地
            curl -sSL https://raw.githubusercontent.com/sillda76/owqq/refs/heads/main/install_fail2ban.sh | bash
            if [ $? -eq 0 ]; then
                echo "[fail2ban安装] fail2ban 安装完成"
            else
                echo "错误：fail2ban 安装失败！"
            fi
            ;;
        n|N)
            echo "[fail2ban安装] 跳过 fail2ban 安装"
            ;;
        *)
            echo "错误：无效输入，跳过 fail2ban 安装"
            ;;
    esac
}

# ---------------------------
# DNS 配置修改函数
# ---------------------------
function configure_dns() {
    echo "----------------------------------------"
    echo "[DNS配置] 当前 DNS 配置如下："
    grep "nameserver" /etc/resolv.conf
    echo "----------------------------------------"
    echo "[DNS配置] 请选择 DNS 配置优化方案："
    echo "1. 国外DNS优化: v4: 1.1.1.1 8.8.8.8, v6: 2606:4700:4700::1111 2001:4860:4860::8888"
    echo "2. 国内DNS优化: v4: 223.5.5.5 183.60.83.19, v6: 2400:3200::1 2400:da00::6666"
    echo "3. 手动编辑DNS配置"
    echo "4. 保持默认"
    read -p "请输入选项 [1-4]: " dns_choice
    case $dns_choice in
        1)
            echo "[DNS配置] 应用国外DNS优化配置..."
            echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 2606:4700:4700::1111\nnameserver 2001:4860:4860::8888" > /etc/resolv.conf
            ;;
        2)
            echo "[DNS配置] 应用国内DNS优化配置..."
            echo -e "nameserver 223.5.5.5\nnameserver 183.60.83.19\nnameserver 2400:3200::1\nnameserver 2400:da00::6666" > /etc/resolv.conf
            ;;
        3)
            echo "[DNS配置] 手动编辑DNS配置..."
            # 采用编辑器 nano 进行手动编辑（可根据需要修改为其他编辑器）
            nano /etc/resolv.conf
            ;;
        4)
            echo "[DNS配置] 保持默认DNS配置"
            ;;
        *)
            echo "错误：无效输入，保持默认DNS配置"
            ;;
    esac
    # 锁定 /etc/resolv.conf 文件，防止被自动重置
    chattr +i /etc/resolv.conf
    echo "[DNS配置] /etc/resolv.conf 文件已加锁"
}

# ---------------------------
# 安装 1panel 函数
# ---------------------------
function install_1panel() {
    echo "----------------------------------------"
    echo "[1panel安装] 是否安装 1panel？"
    read -p "请输入 (y/n): " panel_choice
    case $panel_choice in
        y|Y)
            # 检测系统发行版信息
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [[ "$ID" == "ubuntu" ]]; then
                    echo "[1panel安装] 检测到 Ubuntu 系统，正在安装 1panel..."
                    curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sudo bash quick_start.sh
                elif [[ "$ID" == "debian" ]]; then
                    echo "[1panel安装] 检测到 Debian 系统，正在安装 1panel..."
                    curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && bash quick_start.sh
                else
                    echo "错误：不支持的系统类型，跳过 1panel 安装"
                fi
            else
                echo "错误：无法检测系统信息，跳过 1panel 安装"
            fi
            ;;
        n|N)
            echo "[1panel安装] 跳过 1panel 安装"
            ;;
        *)
            echo "错误：无效输入，跳过 1panel 安装"
            ;;
    esac
}

# ---------------------------
# 脚本入口
# 检查是否以 root 身份运行
# ---------------------------
if [ "$EUID" -ne 0 ]; then
    echo "错误：请以 root 身份运行此脚本！"
    exit 1
fi

# 显示主菜单
main_menu
