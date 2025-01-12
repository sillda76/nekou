#!/bin/bash

# 脚本名称
SCRIPT_NAME="vps-tools.sh"
# 快捷启动命令
ALIAS_NAME="o"

# 主菜单函数
function show_menu() {
    # 清屏（可选）
    clear

    # 主标题
    echo "======================"
    echo "https://github.com/sillda76/vps-scripts"
    echo "======================"
    echo ""

    # 显示选项菜单
    echo "请选择一个选项："
    echo "1. 设置禁Ping"
    echo "2. 安装fail2ban防SSH爆破"
    echo "99. 卸载脚本并删除快捷启动命令"
    echo ""
}

# 安装脚本和快捷启动命令
function install_script() {
    # 下载脚本到当前目录
    if [ ! -f "$SCRIPT_NAME" ]; then
        curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/main/vps-script.sh -o "$SCRIPT_NAME"
        chmod +x "$SCRIPT_NAME"
    fi

    # 设置快捷启动命令
    if ! grep -q "alias $ALIAS_NAME" ~/.bashrc; then
        echo "alias $ALIAS_NAME='$(pwd)/$SCRIPT_NAME'" >> ~/.bashrc
        source ~/.bashrc
    fi
}

# 卸载脚本和快捷启动命令
function uninstall_script() {
    # 删除快捷启动命令
    if grep -q "alias $ALIAS_NAME" ~/.bashrc; then
        sed -i "/alias $ALIAS_NAME/d" ~/.bashrc
        source ~/.bashrc
    fi

    # 删除脚本文件
    if [ -f "$SCRIPT_NAME" ]; then
        rm -f "$SCRIPT_NAME"
    fi

    echo "卸载完成！"
}

# 主循环
function main() {
    show_menu

    # 读取用户输入
    read -p "请输入选项数字: " choice

    # 根据用户输入执行对应的操作
    case $choice in
        1)
            echo "正在设置禁Ping..."
            bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/toggle_ping.sh)
            ;;
        2)
            echo "正在安装fail2ban防SSH爆破..."
            bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/install_fail2ban.sh)
            ;;
        99)
            uninstall_script
            exit 0
            ;;
        *)
            echo "输入错误，请输入有效的选项数字！"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main
            ;;
    esac

    # 操作完成后，等待用户按任意键返回主菜单
    read -n 1 -s -r -p "操作完成，按任意键返回主菜单..."
    main
}

# 安装脚本和快捷启动命令（首次运行时）
if [ ! -f "$SCRIPT_NAME" ]; then
    install_script
fi

# 启动主循环
main
