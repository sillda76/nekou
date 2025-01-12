#!/bin/bash

# 脚本名称
SCRIPT_NAME="vps-owqq.sh"

# 下载脚本的 URL
SCRIPT_URL="https://raw.githubusercontent.com/sillda76/vps-scripts/main/vps-owqq.sh"

# 检查脚本是否存在，如果不存在则下载
if [[ ! -f "$SCRIPT_NAME" ]]; then
    curl -sL "$SCRIPT_URL" -o "$SCRIPT_NAME" > /dev/null
    chmod +x "$SCRIPT_NAME"
fi

# 设置 q 键为启动脚本的快捷键
set_q_shortcut() {
    local shell_rc_file
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc_file="$HOME/.zshrc"
    else
        shell_rc_file="$HOME/.bashrc"
    fi

    # 检查是否已经设置了 q 快捷键
    if ! grep -q 'bind -x '"'\"q\": \"./$SCRIPT_NAME\"'" "$shell_rc_file"; then
        echo "bind -x '\"q\": \"./$SCRIPT_NAME\"'" >> "$shell_rc_file"
        source "$shell_rc_file"
    fi
}

# 移除 q 键快捷键绑定
remove_q_shortcut() {
    local shell_rc_file
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc_file="$HOME/.zshrc"
    else
        shell_rc_file="$HOME/.bashrc"
    fi

    # 移除 q 快捷键绑定
    sed -i '/bind -x '\''"q": "\."\/vps-owqq\.sh"'\''/d' "$shell_rc_file"
    echo "已移除 q 快捷键绑定。"
}

# 显示菜单函数
show_menu() {
    clear
    echo "https://github.com/sillda76/vps-scripts"
    echo "请选择一个选项："
    echo "1. fail2ban安装/管理"
    echo "2. 禁Ping设置"
    echo "00. 更新脚本"
    echo "99. 卸载脚本"
    echo "0. 退出脚本"
}

# 退出确认函数
confirm_exit() {
    read -n 1 -p "确认退出脚本吗？(y/n): " confirm
    echo
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "退出脚本..."
        exit 0
    else
        echo "取消退出，返回菜单..."
        sleep 1
    fi
}

# 更新脚本函数
update_script() {
    echo "正在更新脚本..."
    curl -sL "$SCRIPT_URL" -o "$SCRIPT_NAME" > /dev/null
    chmod +x "$SCRIPT_NAME"
    echo "脚本已更新。"
    sleep 1
}

# 卸载脚本函数
uninstall_script() {
    echo "正在卸载脚本..."
    remove_q_shortcut
    rm -f "$SCRIPT_NAME"
    echo "脚本已卸载。"
    exit 0
}

# 主循环
main() {
    while true; do
        show_menu
        read -n 2 -p "请输入选项数字: " choice
        echo

        case $choice in
            1)
                echo "正在安装/管理 fail2ban..."
                bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/install_fail2ban.sh)
                ;;
            2)
                echo "正在设置禁Ping..."
                bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/toggle_ping.sh)
                ;;
            00)
                update_script
                ;;
            99)
                uninstall_script
                ;;
            0)
                confirm_exit
                ;;
            *)
                echo "无效的选项，请按任意键返回菜单..."
                read -n 1 -s
                ;;
        esac
    done
}

# 首次运行时设置 q 快捷键
set_q_shortcut

# 启动主菜单
main
