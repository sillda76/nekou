#!/bin/bash

# 定义颜色变量（加粗）
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
ORANGE='\033[1;38;5;208m'
MAGENTA='\033[1;35m'
LIGHT_BLUE='\033[1;94m'
LIGHT_GREEN='\033[1;92m'
LIGHT_RED='\033[1;91m'
PINK='\033[1;95m'
TEAL='\033[1;36m'
NC='\033[0m' # 恢复默认颜色

# 当前脚本路径
CURRENT_SCRIPT_PATH="$(pwd)/vps-owqq.sh"

# 脚本 URL
SCRIPT_URL="https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/vps-owqq.sh"

# 显示菜单
show_menu() {
    clear
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${GREEN}VPS Manager${NC}"
    echo -e "${BLUE}https://github.com/sillda76/vps-scripts${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${YELLOW}1. 修改SSH端口${NC}"
    echo -e "${CYAN}2. 系统更新${NC}"
    echo -e "${ORANGE}3. 系统清理${NC}"
    echo -e "${PINK}4. Fail2ban配置${NC}"
    echo -e "${LIGHT_BLUE}5. 禁Pin设置${NC}"
    echo -e "${TEAL}6. 添加系统信息${NC}"
    echo -e "${LIGHT_GREEN}7. 安装1Panel${NC}"
    echo -e "${LIGHT_BLUE}8. 系统工具${NC}"
    echo -e "${LIGHT_RED}9. 虚拟环境${NC}"  # 新增选项
    echo -e "${LIGHT_RED}00. 更新脚本${NC}"
    echo -e "${RED}99. 卸载脚本${NC}"
    echo -e "${MAGENTA}0. 退出脚本${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# 显示1Panel子菜单
show_1panel_menu() {
    clear
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${GREEN}1Panel 管理${NC}"
    echo -e "${BLUE}官网: https://1panel.cn/${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${YELLOW}1. 查看1Panel面板信息${NC}"
    echo -e "${CYAN}2. 修改1Panel面板密码${NC}"
    echo -e "${ORANGE}3. 卸载1Panel面板${NC}"
    echo -e "${MAGENTA}0. 返回主菜单${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# 显示系统工具子菜单
show_system_tools_menu() {
    clear
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${GREEN}系统工具${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${YELLOW}1. 安装 htop (系统监控工具)${NC}"
    echo -e "${CYAN}2. 安装 iftop (网络流量监控工具)${NC}"
    echo -e "${ORANGE}3. 安装 vim (文本编辑器)${NC}"
    echo -e "${PINK}4. 安装 curl (网络工具)${NC}"
    echo -e "${LIGHT_BLUE}5. 安装 wget (下载工具)${NC}"
    echo -e "${TEAL}6. 安装 git (版本控制工具)${NC}"
    echo -e "${LIGHT_GREEN}7. 安装 tmux (终端复用工具)${NC}"
    echo -e "${LIGHT_BLUE}8. 安装 unzip (解压工具)${NC}"
    echo -e "${LIGHT_RED}9. 安装 tar (归档工具)${NC}"
    echo -e "${MAGENTA}10. 安装 nano (文本编辑器)${NC}"
    echo -e "${LIGHT_GREEN}11. 一键安装全部系统基础工具${NC}"
    echo -e "${YELLOW}12. 安装 ffmpeg (多媒体处理工具)${NC}"  # 新增选项
    echo -e "${MAGENTA}0. 返回主菜单${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# 显示虚拟环境子菜单
show_virtualenv_menu() {
    clear
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${GREEN}虚拟环境管理${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${YELLOW}1. 安装虚拟环境${NC}"
    echo -e "${CYAN}2. 在当前目录创建虚拟环境${NC}"
    echo -e "${ORANGE}3. 进入当前目录的虚拟环境${NC}"
    echo -e "${PINK}4. 卸载当前目录下的虚拟环境${NC}"
    echo -e "${LIGHT_BLUE}5. 卸载虚拟环境${NC}"
    echo -e "${MAGENTA}0. 返回主菜单${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# 安装系统工具函数
install_system_tool() {
    local tool_name=$1
    local install_command=$2
    echo -e "${YELLOW}正在安装 ${tool_name}...${NC}"
    if eval "$install_command"; then
        echo -e "${GREEN}${tool_name} 安装成功！${NC}"
    else
        echo -e "${RED}${tool_name} 安装失败，请检查网络连接或包管理器。${NC}"
    fi
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 一键安装全部系统基础工具
install_all_system_tools() {
    tools=(
        "htop"
        "iftop"
        "vim"
        "curl"
        "wget"
        "git"
        "tmux"
        "unzip"
        "tar"
        "nano"
    )
    for tool in "${tools[@]}"; do
        install_system_tool "$tool" "install_package $tool"
    done
    echo -e "${GREEN}所有系统基础工具安装完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 安装1Panel函数
install_1panel() {
    if command -v 1pctl &>/dev/null; then
        while true; do
            show_1panel_menu
            read -p "请输入选项数字: " sub_choice
            case $sub_choice in
                1)
                    echo -e "${YELLOW}正在查看1Panel面板信息...${NC}"
                    1pctl user-info
                    read -n 1 -s -r -p "按任意键返回菜单..."
                    ;;
                2)
                    echo -e "${YELLOW}正在修改1Panel面板密码...${NC}"
                    1pctl update password
                    read -n 1 -s -r -p "按任意键返回菜单..."
                    ;;
                3)
                    echo -e "${YELLOW}是否确认卸载1Panel？(y/n): ${NC}"
                    read uninstall_choice
                    if [[ "$uninstall_choice" == "y" ]]; then
                        echo -e "${YELLOW}正在卸载1Panel面板...${NC}"
                        1pctl uninstall
                        echo -e "${GREEN}1Panel 卸载完成！${NC}"
                    else
                        echo -e "${YELLOW}已取消卸载。${NC}"
                    fi
                    read -n 1 -s -r -p "按任意键返回菜单..."
                    break
                    ;;
                0)
                    echo -e "${MAGENTA}返回主菜单。${NC}"
                    break
                    ;;
                "")
                    echo -e "${RED}错误：未输入选项，请按任意键返回菜单。${NC}"
                    read -n 1 -s -r -p ""
                    ;;
                *)
                    echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"
                    read -n 1 -s -r -p ""
                    ;;
            esac
        done
    else
        echo -e "${YELLOW}1Panel 未安装。${NC}"
        read -p "是否安装 1Panel？(y/n): " install_choice
        if [[ "$install_choice" == "y" ]]; then
            echo -e "${YELLOW}正在安装 1Panel...${NC}"
            curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sh quick_start.sh
            echo -e "${GREEN}1Panel 安装成功！${NC}"
        else
            echo -e "${YELLOW}已取消安装。${NC}"
        fi
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 系统工具函数
system_tools() {
    while true; do
        show_system_tools_menu
        read -p "请输入选项数字: " sub_choice
        case $sub_choice in
            1)
                install_system_tool "htop" "install_package htop"
                ;;
            2)
                install_system_tool "iftop" "install_package iftop"
                ;;
            3)
                install_system_tool "vim" "install_package vim"
                ;;
            4)
                install_system_tool "curl" "install_package curl"
                ;;
            5)
                install_system_tool "wget" "install_package wget"
                ;;
            6)
                install_system_tool "git" "install_package git"
                ;;
            7)
                install_system_tool "tmux" "install_package tmux"
                ;;
            8)
                install_system_tool "unzip" "install_package unzip"
                ;;
            9)
                install_system_tool "tar" "install_package tar"
                ;;
            10)
                install_system_tool "nano" "install_package nano"
                ;;
            11)
                install_all_system_tools
                ;;
            12)  # 新增的 ffmpeg 选项
                install_system_tool "ffmpeg" "install_package ffmpeg"
                ;;
            0)
                echo -e "${MAGENTA}返回主菜单。${NC}"
                break
                ;;
            "")
                echo -e "${RED}错误：未输入选项，请按任意键返回菜单。${NC}"
                read -n 1 -s -r -p ""
                ;;
            *)
                echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"
                read -n 1 -s -r -p ""
                ;;
        esac
    done
}

# 安装包管理器通用函数
install_package() {
    local package=$1
    if command -v apt &>/dev/null; then
        apt install -y "$package"
    elif command -v yum &>/dev/null; then
        yum install -y "$package"
    elif command -v dnf &>/dev/null; then
        dnf install -y "$package"
    elif command -v pacman &>/dev/null; then
        pacman -S --noconfirm "$package"
    elif command -v zypper &>/dev/null; then
        zypper install -y "$package"
    elif command -v apk &>/dev/null; then
        apk add --no-cache "$package"
    else
        echo -e "${RED}未知的包管理器，无法安装 ${package}。${NC}"
        return 1
    fi
}

# 更新脚本函数
update_script() {
    echo -e "${YELLOW}正在更新脚本...${NC}"
    if curl -s "$SCRIPT_URL" -o "$CURRENT_SCRIPT_PATH"; then
        chmod +x "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本更新成功！按任意键返回菜单。${NC}"
        read -n 1 -s -r -p ""
        exec "$CURRENT_SCRIPT_PATH"
    else
        echo -e "${RED}脚本更新失败，请检查网络连接或 URL 是否正确。${NC}"
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 系统更新函数
system_update() {
    echo -e "${YELLOW}正在系统更新...${NC}"
    if command -v apt &>/dev/null; then
        apt update -y && apt upgrade -y && apt dist-upgrade -y && apt autoremove -y
    elif command -v yum &>/dev/null; then
        yum update -y && yum upgrade -y
    elif command -v dnf &>/dev/null; then
        dnf update -y && dnf upgrade -y
    elif command -v pacman &>/dev/null; then
        pacman -Syu --noconfirm
    elif command -v zypper &>/dev/null; then
        zypper refresh && zypper update -y
    elif command -v apk &>/dev/null; then
        apk update && apk upgrade
    else
        echo -e "${RED}未知的包管理器，无法执行系统更新。${NC}"
    fi
    echo -e "${GREEN}系统更新完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 系统清理函数
linux_clean() {
    echo -e "${YELLOW}正在系统清理...${NC}"

    # 清理步骤
    steps=(
        "清理包管理器缓存..."
        "删除系统日志..."
        "删除临时文件..."
        "清理 APK 缓存..."
        "清理 YUM/DNF 缓存..."
        "清理 APT 缓存..."
        "清理 Pacman 缓存..."
        "清理 Zypper 缓存..."
        "清理 Opkg 缓存..."
    )

    # 总步骤数
    total_steps=${#steps[@]}

    # 显示清理内容
    echo -e "${YELLOW}本次清理将执行以下操作：${NC}"
    for step in "${steps[@]}"; do
        echo -e "  - ${step}"
    done
    echo -e "${YELLOW}开始清理...${NC}"

    for ((i = 0; i < total_steps; i++)); do
        # 显示当前清理步骤
        echo -e "${YELLOW}${steps[$i]}${NC}"

        # 执行清理操作
        case ${steps[$i]} in
            "清理包管理器缓存...")
                if command -v dnf &>/dev/null; then
                    dnf clean all
                elif command -v yum &>/dev/null; then
                    yum clean all
                elif command -v apt &>/dev/null; then
                    apt clean
                    apt autoclean
                elif command -v apk &>/dev/null; then
                    apk cache clean
                elif command -v pacman &>/dev/null; then
                    pacman -Scc --noconfirm
                elif command -v zypper &>/dev/null; then
                    zypper clean --all
                elif command -v opkg &>/dev/null; then
                    opkg clean
                fi
                ;;
            "删除系统日志...")
                journalctl --rotate
                journalctl --vacuum-time=1s
                journalctl --vacuum-size=500M
                ;;
            "删除临时文件...")
                rm -rf /tmp/*
                rm -rf /var/tmp/*
                ;;
            "清理 APK 缓存...")
                if command -v apk &>/dev/null; then
                    apk cache clean
                fi
                ;;
            "清理 YUM/DNF 缓存...")
                if command -v dnf &>/dev/null; then
                    dnf clean all
                elif command -v yum &>/dev/null; then
                    yum clean all
                fi
                ;;
            "清理 APT 缓存...")
                if command -v apt &>/dev/null; then
                    apt clean
                    apt autoclean
                fi
                ;;
            "清理 Pacman 缓存...")
                if command -v pacman &>/dev/null; then
                    pacman -Scc --noconfirm
                fi
                ;;
            "清理 Zypper 缓存...")
                if command -v zypper &>/dev/null; then
                    zypper clean --all
                fi
                ;;
            "清理 Opkg 缓存...")
                if command -v opkg &>/dev/null; then
                    opkg clean
                fi
                ;;
        esac
    done

    echo -e "\n${GREEN}系统清理完成！${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 设置快捷启动命令
setup_alias() {
    local config_files=(~/.bashrc ~/.zshrc ~/.profile)  # 所有配置文件

    for shell_rc in "${config_files[@]}"; do
        # 如果配置文件不存在，则创建它
        if [[ ! -f "$shell_rc" ]]; then
            touch "$shell_rc"
            echo -e "${GREEN}创建配置文件: $shell_rc${NC}"
        fi

        # 检查是否已经存在快捷命令
        if ! grep -q "alias q=" "$shell_rc"; then
            echo "alias q='$CURRENT_SCRIPT_PATH'" >> "$shell_rc"
            echo -e "${GREEN}快捷命令 'q' 已添加到 $shell_rc。${NC}"
        else
            echo -e "${YELLOW}快捷命令 'q' 已存在于 $shell_rc。${NC}"
        fi
    done

    # 重新加载当前 Shell 的配置文件
    if [[ -n "$SHELL" ]]; then
        source ~/.profile  # 重新加载通用配置文件
        case $(basename "$SHELL") in
            "zsh") source ~/.zshrc ;;
            "bash") source ~/.bashrc ;;
        esac
        echo -e "${GREEN}配置文件已重新加载。${NC}"
    else
        echo -e "${RED}无法重新加载配置文件。${NC}"
    fi
}

# 卸载脚本函数
uninstall_script() {
    echo -e "${YELLOW}正在卸载脚本...${NC}"
    local config_files=(~/.bashrc ~/.zshrc ~/.profile)  # 所有配置文件

    for shell_rc in "${config_files[@]}"; do
        # 删除快捷命令
        if grep -q "alias q=" "$shell_rc"; then
            sed -i '/alias q=/d' "$shell_rc"
            echo -e "${GREEN}快捷启动命令 'q' 已从 $shell_rc 中删除。${NC}"
        else
            echo -e "${YELLOW}快捷启动命令 'q' 不存在于 $shell_rc。${NC}"
        fi
    done

    # 删除标记文件
    if [[ -f ~/.vps-script-setup ]]; then
        rm -f ~/.vps-script-setup
        echo -e "${GREEN}标记文件 ~/.vps-script-setup 已删除。${NC}"
    fi

    # 删除脚本文件
    if [[ -f "$CURRENT_SCRIPT_PATH" ]]; then
        rm -f "$CURRENT_SCRIPT_PATH"
        echo -e "${GREEN}脚本文件 $CURRENT_SCRIPT_PATH 已删除。${NC}"
    else
        echo -e "${YELLOW}脚本文件 $CURRENT_SCRIPT_PATH 不存在。${NC}"
    fi

    echo -e "${GREEN}脚本卸载完成。${NC}"
    exit 0
}

# 虚拟环境管理函数
virtualenv_management() {
    while true; do
        show_virtualenv_menu
        read -p "请输入选项数字: " sub_choice
        case $sub_choice in
            1) install_virtualenv ;;
            2) create_virtualenv ;;
            3) activate_virtualenv ;;
            4) remove_current_virtualenv ;;
            5) uninstall_virtualenv ;;
            0) echo -e "${MAGENTA}返回主菜单。${NC}"; break ;;
            "") echo -e "${RED}错误：未输入选项，请按任意键返回菜单。${NC}"; read -n 1 -s -r -p "" ;;
            *) echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"; read -n 1 -s -r -p "" ;;
        esac
    done
}

# 安装虚拟环境
install_virtualenv() {
    echo -e "${YELLOW}正在安装虚拟环境...${NC}"
    apt update
    apt install -y python3-venv
    if command -v python3 &>/dev/null; then
        echo -e "${GREEN}虚拟环境安装成功！${NC}"
    else
        echo -e "${RED}虚拟环境安装失败，请检查网络连接或包管理器。${NC}"
    fi
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 创建虚拟环境
create_virtualenv() {
    echo -e "${YELLOW}正在创建虚拟环境...${NC}"
    if command -v python3 &>/dev/null; then
        python3 -m venv venv
        if [[ -d "venv" ]]; then
            echo -e "${GREEN}虚拟环境创建成功！${NC}"
            echo -e "${CYAN}激活虚拟环境的命令是：source venv/bin/activate${NC}"
        else
            echo -e "${RED}虚拟环境创建失败，请检查当前目录权限或 Python 环境。${NC}"
        fi
    else
        echo -e "${RED}Python3 未安装，请先安装 Python3。${NC}"
    fi
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 进入虚拟环境
activate_virtualenv() {
    if [[ -d "venv" ]]; then
        echo -e "${YELLOW}正在激活虚拟环境...${NC}"
        source venv/bin/activate
        echo -e "${GREEN}虚拟环境已激活。${NC}"
        echo -e "${CYAN}退出脚本并进入虚拟环境。${NC}"
        exit 0  # 退出脚本
    else
        echo -e "${RED}当前目录下无虚拟环境，请先创建虚拟环境。${NC}"
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 卸载当前目录下的虚拟环境
remove_current_virtualenv() {
    if [[ -d "venv" ]]; then
        echo -e "${YELLOW}正在卸载当前目录下的虚拟环境...${NC}"
        rm -rf venv
        echo -e "${GREEN}虚拟环境已卸载。${NC}"
    else
        echo -e "${RED}当前目录下无虚拟环境。${NC}"
    fi
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 卸载虚拟环境
uninstall_virtualenv() {
    echo -e "${YELLOW}正在卸载虚拟环境...${NC}"
    apt remove -y python3-venv
    echo -e "${GREEN}虚拟环境已卸载。${NC}"
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项数字: " choice
    case $choice in
        1) bash <(curl -s https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/ssh_port_chg.sh) ;;
        2) system_update ;;
        3) linux_clean ;;
        4) bash <(curl -sL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/install_fail2ban.sh) ;;
        5) bash <(curl -fsSL https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/ping-control.sh) ;;
        6) bash <(curl -s https://raw.githubusercontent.com/sillda76/vps-scripts/refs/heads/main/system_info.sh) ;;
        7) install_1panel ;;
        8) system_tools ;;
        9) virtualenv_management ;;  # 新增虚拟环境管理
        00) update_script ;;
        99) uninstall_script ;;
        0) echo -e "${MAGENTA}退出脚本。${NC}"; break ;;
        "") echo -e "${RED}错误：未输入选项，请按任意键返回菜单。${NC}"; read -n 1 -s -r -p "" ;;
        *) echo -e "${RED}错误：无效选项，请按任意键返回菜单。${NC}"; read -n 1 -s -r -p "" ;;
    esac
done

# 首次运行脚本时自动设置快捷命令
if [[ ! -f ~/.vps-script-setup ]]; then
    setup_alias
    touch ~/.vps-script-setup
    echo -e "${GREEN}首次运行完成，快捷命令已设置。${NC}"
fi
