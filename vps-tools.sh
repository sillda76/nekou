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
    echo "VPS 管理工具"
    echo "https://github.com/sillda76/vps-scripts"
    echo "======================"
    echo ""

    # 显示选项菜单
    echo "请选择一个选项："
    echo "1. 设置禁Ping"
    echo "2. 安装 fail2ban 防 SSH 爆破"
    echo "99. 卸载脚本并删除快捷启动命令"
    echo ""
}

# 安装脚本和快捷启动命令
function install_script() {
    # 下载脚本到当前目录
    if [ ! -f "$SCRIPT_NAME" ]; then
        echo "正在下载脚本..."
        if curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/main/vps-tools.sh -o "$SCRIPT_NAME"; then
            chmod +x "$SCRIPT_NAME"
            echo "脚本下载成功！"
        else
            echo "脚本下载失败，请检查网络连接！"
            exit 1
        fi
    fi

    # 设置快捷启动命令
    if ! grep -q "alias $ALIAS_NAME" ~/.bashrc; then
        echo "alias $ALIAS_NAME='$(pwd)/$SCRIPT_NAME'" >> ~/.bashrc
        source ~/.bashrc
        echo "快捷启动命令 '$ALIAS_NAME' 设置成功！"
    fi
}

# 卸载脚本和快捷启动命令
function uninstall_script() {
    # 删除快捷启动命令
    if grep -q "alias $ALIAS_NAME" ~/.bashrc; then
        sed -i "/alias $ALIAS_NAME/d" ~/.bashrc
        source ~/.bashrc
        echo "快捷启动命令 '$ALIAS_NAME' 已删除！"
    fi

    # 删除脚本文件
    if [ -f "$SCRIPT_NAME" ]; then
        rm -f "$SCRIPT_NAME"
        echo "脚本文件 '$SCRIPT_NAME' 已删除！"
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
            if bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/toggle_ping.sh); then
                echo "禁Ping设置成功！"
            else
                echo "禁Ping设置失败！"
            fi
            ;;
        2)
            echo "正在安装 fail2ban 防 SSH 爆破..."
            if bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/install_fail2ban.sh); then
                echo "fail2ban 安装成功！"
            else
                echo "fail2ban 安装失败！"
            fi
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
