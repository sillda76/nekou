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

# 显示菜单函数
show_menu() {
    clear
    echo "https://github.com/sillda76/vps-scripts"
    echo "请选择一个选项："
    echo "1. fail2ban安装/管理"
    echo "2. 禁Ping设置"
    echo "0. 退出脚本"
}

# 主循环
main() {
    while true; do
        show_menu
        read -n 1 -p "请输入选项数字: " choice
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
            0)
                echo "退出脚本..."
                exit 0
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
