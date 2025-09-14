#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "开始针对 Ubuntu/Debian/macOS 安装 Zsh 和常用插件"

# --- Helper function to check and run commands ---
run_command() {
    if command -v "$1" &> /dev/null; then
        echo "'$1' 已安装."
        return 0
    else
        echo "准备安装 '$1'..."
        return 1
    fi
}

# --- Detect OS and Package Manager ---
detect_os_package_manager() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &> /dev/null; then
            echo "检测到 Linux (可能为 Ubuntu/Debian)，使用 apt 进行包管理。"
            PACKAGE_MANAGER="apt"
            UPDATE_CMD="sudo apt update"
            INSTALL_CMD="sudo apt install -y"
        elif command -v dnf &> /dev/null; then
             echo "检测到 Linux (可能为 Fedora/CentOS)，使用 dnf 进行包管理。"
             PACKAGE_MANAGER="dnf"
             UPDATE_CMD="" # dnf install handles updates implicitly
             INSTALL_CMD="sudo dnf install -y"
        elif command -v yum &> /dev/null; then
             echo "检测到 Linux (可能为 CentOS/RHLE)，使用 yum 进行包管理。"
             PACKAGE_MANAGER="yum"
             UPDATE_CMD="" # yum install handles updates implicitly
             INSTALL_CMD="sudo yum install -y"
        else
            echo "未检测到支持的 Linux 包管理器 (apt, dnf, yum)。"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            echo "检测到 macOS，使用 Homebrew (brew) 进行包管理。"
            PACKAGE_MANAGER="brew"
            UPDATE_CMD="brew update"
            INSTALL_CMD="brew install"
        else
            echo "在 macOS 上未检测到 Homebrew (brew)。请先安装 Homebrew (https://brew.sh)。"
            exit 1
        fi
    else
        echo "不支持的操作系统类型 '$OSTYPE'。"
        exit 1
    fi
}

# Call the detection function
detect_os_package_manager

# --- Install Package Function using detected manager ---
install_package() {
    local package_name="$1"
    if run_command "$package_name"; then
        return 0 # Already installed
    fi

    echo "Installing '$package_name' using $PACKAGE_MANAGER..."

    if [ -n "$UPDATE_CMD" ]; then
       $UPDATE_CMD || echo "包管理器更新失败，尝试跳过更新继续安装..."
    fi

    $INSTALL_CMD "$package_name" || {
        echo "安装 '$package_name' 失败。请手动运行 '$INSTALL_CMD $package_name' 查看错误信息。"
        exit 1
    }

    if command -v "$package_name" &> /dev/null; then
        echo "'$package_name' 安装成功."
    else
        echo "'$package_name' 安装后未找到可执行文件。请手动检查问题。"
        exit 1
    fi
}


# --- 1. Install Git ---
install_package git

# --- 2. Install Zsh ---
install_package zsh

# --- 3. Install Oh My Zsh ---
OHMYZSH_DIR="$HOME/.oh-my-zsh"
# 使用最新的安装URL
OHMYZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

if [ -d "$OHMYZSH_DIR" ]; then
    echo "Oh My Zsh 已安装."
else
    echo "安装 Oh My Zsh (从 $OHMYZSH_INSTALL_URL)..."
    # 创建临时文件保存安装脚本
    TEMP_INSTALL_SCRIPT=$(mktemp)
    
    # 下载安装脚本到临时文件
    if curl -fsSL "$OHMYZSH_INSTALL_URL" -o "$TEMP_INSTALL_SCRIPT"; then
        echo "Oh My Zsh 安装脚本下载成功。"
        
        # 检查脚本内容以确保下载完整
        if [ -s "$TEMP_INSTALL_SCRIPT" ]; then
            echo "安装脚本内容检查通过。"
        else
            echo "安装脚本下载不完整（文件为空）。请检查网络连接。"
            rm -f "$TEMP_INSTALL_SCRIPT"
            exit 1
        fi
        
        # 设置权限
        chmod +x "$TEMP_INSTALL_SCRIPT"
        
        # 执行安装脚本，不自动切换shell和不立即启动zsh
        CHSH=no RUNZSH=no sh "$TEMP_INSTALL_SCRIPT" || {
            echo "Oh My Zsh 安装脚本执行失败。"
            rm -f "$TEMP_INSTALL_SCRIPT"
            exit 1
        }
        
        # 清理临时文件
        rm -f "$TEMP_INSTALL_SCRIPT"
    else
        echo "Oh My Zsh 安装脚本下载失败。请检查网络连接或尝试更换安装URL。"
        exit 1
    fi

    if [ -d "$OHMYZSH_DIR" ]; then
        echo "Oh My Zsh 安装成功."
        # Oh My Zsh installer copies .zshrc, let's make sure it exists
        if [ ! -f "$HOME/.zshrc" ]; then
             echo "Oh My Zsh 安装成功，但 ~/.zshrc 文件未生成。创建备用配置文件..."
             # Attempt to copy template if it exists
             if [ -f "$OHMYZSH_DIR/templates/zshrc.zsh-template" ]; then
                 cp "$OHMYZSH_DIR/templates/zshrc.zsh-template" "$HOME/.zshrc"
                 echo "已从模板创建 ~/.zshrc 文件。"
             else
                 echo "无法找到 ~/.zshrc 模板文件。创建最小配置..."
                 cat > "$HOME/.zshrc" << EOL
# 基本 Oh-My-Zsh 配置
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh
EOL
                echo "已创建基本 ~/.zshrc 文件。"
             fi
        fi
    else
        echo "Oh My Zsh 安装失败。请手动检查问题或网络连接。"
        exit 1
    fi
fi


# --- 4. Install zsh-autosuggestions plugin ---
AUTOSUGGESTIONS_DIR=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
if [ -d "$AUTOSUGGESTIONS_DIR" ]; then
    echo "zsh-autosuggestions 插件已安装."
else
    echo "安装 zsh-autosuggestions 插件..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGESTIONS_DIR" || {
        echo "zsh-autosuggestions 插件安装失败。"
        echo "尝试使用国内镜像源安装..."
        git clone --depth=1 https://gitee.com/mirrors/zsh-autosuggestions "$AUTOSUGGESTIONS_DIR" || {
            echo "zsh-autosuggestions 插件安装失败。请手动检查问题。"
        }
    }
fi

# --- 5. Install zsh-syntax-highlighting plugin ---
HIGHLIGHTING_DIR=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
if [ -d "$HIGHLIGHTING_DIR" ]; then
    echo "zsh-syntax-highlighting 插件已安装."
else
    echo "安装 zsh-syntax-highlighting 插件..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$HIGHLIGHTING_DIR" || {
        echo "zsh-syntax-highlighting 插件安装失败。"
        echo "尝试使用国内镜像源安装..."
        git clone --depth=1 https://gitee.com/mirrors/zsh-syntax-highlighting "$HIGHLIGHTING_DIR" || {
            echo "zsh-syntax-highlighting 插件安装失败。请手动检查问题。"
        }
    }
fi

# --- 6. Install Starship ---
if run_command starship; then
    echo "Starship 已安装."
else
    echo "安装 Starship..."
    if [[ "$PACKAGE_MANAGER" == "brew" ]]; then
        $INSTALL_CMD starship
    else
        # 使用官方安装脚本
        curl -sS https://starship.rs/install.sh | sh
    fi
    
    # 验证安装
    if run_command starship; then
        echo "Starship 安装成功."
    else
        echo "Starship 安装失败。请手动检查问题。"
        exit 1
    fi
fi

# --- 7. Configure plugins in .zshrc ---
ZSHRC="$HOME/.zshrc"
echo "配置 ~/.zshrc 文件..."

update_plugins() {
    # 读取现有的plugins行
    local plugins_line=$(grep -E "^[[:space:]]*plugins=\([^)]*\)" "$ZSHRC" || echo "plugins=(git)")
    
    # 为添加的插件名称创建一个临时文件
    local tmp_file=$(mktemp)
    echo "$plugins_line" > "$tmp_file"
    
    # 检查并添加插件
    for plugin in "$@"; do
        if ! grep -q "$plugin" "$tmp_file"; then
            # 在tmp_file中更新插件列表
            sed -i.bak "s/plugins=(\(.*\))/plugins=(\1 $plugin)/" "$tmp_file"
        fi
    done
    
    # 获取更新后的插件行
    local new_plugins_line=$(cat "$tmp_file")
    
    # 如果.zshrc中有plugins行，则替换它；否则添加新行
    if grep -q "^[[:space:]]*plugins=(" "$ZSHRC"; then
        # 使用perl处理，避免sed在不同系统上的差异
        perl -i -pe "s/^[[:space:]]*plugins=\([^)]*\)/$new_plugins_line/" "$ZSHRC"
    else
        # 如果没有找到plugins行，添加到文件末尾
        echo "$new_plugins_line" >> "$ZSHRC"
    fi
    
    # 清理临时文件
    rm -f "$tmp_file" "$tmp_file.bak"
}

if [ -f "$ZSHRC" ]; then
    echo "更新插件配置..."
    update_plugins "zsh-autosuggestions" "zsh-syntax-highlighting"
    
    # 添加 Starship 配置
    if ! grep -q "starship init zsh" "$ZSHRC"; then
        echo "添加 Starship 配置..."
        echo -e "\n# 启用 Starship 提示符\neval \"\$(starship init zsh)\"" >> "$ZSHRC"
    fi
    
    echo "插件配置完成。"
else
    echo "$ZSHRC 文件未找到。创建新的配置文件..."
    cat > "$ZSHRC" << EOL
# 基本 Oh-My-Zsh 配置
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# 启用 Starship 提示符
eval "\$(starship init zsh)"
EOL
    echo "已创建新的 ~/.zshrc 文件并添加插件。"
fi

# --- 8. Set Zsh as default shell (improved for permanent switch) ---
CURRENT_SHELL=$(basename "$SHELL")
ZSH_PATH=$(command -v zsh)

# 确保zsh在/etc/shells中
if [ -n "$ZSH_PATH" ] && ! grep -q "$ZSH_PATH" /etc/shells; then
    echo "将 $ZSH_PATH 添加到 /etc/shells..."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null || {
        echo "无法添加 Zsh 到 /etc/shells，但将继续尝试设置..."
    }
fi

if [ "$CURRENT_SHELL" = "zsh" ]; then
    echo "你的默认 Shell 已经是 Zsh。"
else
    if [ -n "$ZSH_PATH" ]; then
        echo "尝试将 Zsh ($ZSH_PATH) 设置为默认 Shell..."
        
        # 尝试用多种方法设置默认shell
        if [ "$USER" = "root" ]; then
            echo "检测到当前用户是 root，正在设置 Zsh 为默认 shell..."
            chsh -s "$ZSH_PATH" || {
                echo "为 root 用户设置默认 shell 失败，尝试其他方法..."
            }
        else
            # 尝试使用chsh命令
            chsh -s "$ZSH_PATH" || {
                echo "使用 chsh 设置默认 shell 失败，尝试其他方法..."
                # 尝试直接修改/etc/passwd (需要root权限)
                sudo sed -i.bak "s#^\($USER:[^:]*:[^:]*:[^:]*:[^:]*:\)[^:]*\(.*\)#\1$ZSH_PATH\2#" /etc/passwd || {
                    echo "修改 /etc/passwd 失败，尝试最后方法..."
                    # 在.bashrc或.profile中添加exec zsh
                    for rc_file in ~/.bashrc ~/.bash_profile ~/.profile; do
                        if [ -f "$rc_file" ]; then
                            if ! grep -q "exec zsh" "$rc_file"; then
                                echo "添加 'exec zsh' 到 $rc_file..."
                                echo -e "\n# 自动切换到 Zsh\nif [ -x \"$ZSH_PATH\" ]; then\n    exec \"$ZSH_PATH\" -l\nfi" >> "$rc_file"
                                echo "已在 $rc_file 中添加自动切换到 Zsh 的配置。"
                            fi
                        fi
                    done
                }
            }
        fi
        
        # 验证是否成功
        CURRENT_DEFAULT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
        if [ "$CURRENT_DEFAULT_SHELL" = "$ZSH_PATH" ]; then
            echo "Zsh 已永久设置为默认 Shell！"
        else
            echo "已尝试多种方法设置 Zsh 为默认 Shell。"
            echo "如果在下次登录时未自动使用 Zsh，请手动运行 'chsh -s $(command -v zsh)'。"
        fi
    else
        echo "未找到 Zsh 可执行文件。无法设置默认 Shell。"
    fi
fi

# --- 9. Final steps and immediate switch to Zsh ---
echo ""
echo "安装和配置已完成！"
echo "----------------------------------------------------"
echo "现在将立即切换到配置好的 Zsh 环境..."
echo "----------------------------------------------------"

# 添加一个标记文件表示脚本已成功运行过一次
touch "$HOME/.zsh_setup_complete"

# 确保以非交互方式启动zsh以避免阻塞
exec zsh -l

# This line will only be reached if 'exec zsh' fails
echo "切换到 Zsh 失败。请手动运行 'zsh' 或关闭并重新打开终端。"
