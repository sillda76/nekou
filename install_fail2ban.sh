#!/usr/bin/env bash
# install_fail2ban.sh - Debian/Ubuntu 交互脚本（最终版）
# 功能：
#  - 安装并配置 Fail2Ban（仅 SSH），ignoreip 包含 127.0.0.1/8 ::1
#  - 使用明确的 ssh 日志路径（Debian/Ubuntu: /var/log/auth.log 或 /var/log/secure）
#  - 每15天清空 fail2ban 日志（通过 root crontab）
#  - 查看状态、配置、实时日志、查看/解封封禁 IP、卸载并清理 cron & 脚本
set -euo pipefail

# 颜色变量（使用 \033 更稳健）
RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"
BLUE="\033[34m"; CYAN="\033[36m"; BOLD="\033[1m"; RESET="\033[0m"

info(){ printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
warn(){ printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
err(){ printf "${RED}[ERROR]${RESET} %s\n" "$*\n" >&2; exit 1; }

if [ "$EUID" -ne 0 ]; then
  err "请以 root 或 sudo 运行：sudo bash $0"
fi

# ---------- 可调项 ----------
SSH_PORT=22
BANTIME=600                     # 封禁时长（秒）
JAIL="sshd"
JAIL_DIR="/etc/fail2ban/jail.d"
JAIL_FILE="${JAIL_DIR}/sshd-ufw.local"
FAIL2BAN_LOG="/var/log/fail2ban.log"
SSH_AUTH_LOG="/var/log/auth.log"
SSH_SECURE_LOG="/var/log/secure"
CLEAR_SCRIPT="/usr/local/bin/clear_fail2ban_log.sh"
CRON_MARK="# clear_fail2ban_log every 15 days"
CRON_LINE="0 3 */15 * * ${CLEAR_SCRIPT} >/dev/null 2>&1"
SEP="=============================="

press_any(){
  printf "\n${CYAN}按任意键继续...${RESET}"
  read -r -n1 -s
  printf "\n"
}

is_installed(){ command -v "$1" >/dev/null 2>&1; }

show_install_status(){
  if is_installed fail2ban-client || dpkg -s fail2ban >/dev/null 2>&1; then
    printf "${BOLD}Fail2ban:${RESET} ${GREEN}已安装${RESET}    "
  else
    printf "${BOLD}Fail2ban:${RESET} ${RED}未安装${RESET}    "
  fi
  if is_installed ufw || dpkg -s ufw >/dev/null 2>&1; then
    printf "${BOLD}UFW:${RESET} ${GREEN}已安装${RESET}\n"
  else
    printf "${BOLD}UFW:${RESET} ${RED}未安装${RESET}\n"
  fi
}

# 选择合适的 ssh 日志路径
detect_ssh_logpath(){
  if [ -f "${SSH_AUTH_LOG}" ]; then
    printf "%s" "${SSH_AUTH_LOG}"
  elif [ -f "${SSH_SECURE_LOG}" ]; then
    printf "%s" "${SSH_SECURE_LOG}"
  else
    # 修复：当未找到常见日志文件时，不再返回占位符，而是使用明确的默认路径并给出警告
    warn "未找到 ${SSH_AUTH_LOG} 或 ${SSH_SECURE_LOG}。回退到 ${SSH_AUTH_LOG} 作为默认路径（如果系统使用 journal，请调整）。"
    printf "%s" "${SSH_AUTH_LOG}"
  fi
}

# 创建清空日志脚本并添加 cron（若不存在）
setup_periodic_log_clear(){
  cat > "${CLEAR_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
LOG="/var/log/fail2ban.log"
if [ -f "${LOG}" ]; then
  : > "${LOG}"
  chown root:root "${LOG}" 2>/dev/null || true
  chmod 644 "${LOG}" 2>/dev/null || true
fi
EOF
  chmod 755 "${CLEAR_SCRIPT}"
  info "已创建 ${CLEAR_SCRIPT}（用于清空 ${FAIL2BAN_LOG}）"

  CRONTAB_CONTENT="$(crontab -l 2>/dev/null || true)"
  if printf "%s\n" "$CRONTAB_CONTENT" | grep -Fq "${CRON_MARK}"; then
    info "crontab 中已存在定时清理任务，跳过添加。"
  else
    {
      printf "%s\n" "$CRONTAB_CONTENT"
      printf "%s\n" "${CRON_MARK}"
      printf "%s\n" "${CRON_LINE}"
    } | crontab -
    info "已将定时任务添加到 root 的 crontab：${CRON_LINE}"
  fi
}

install_fail2ban(){
  info "开始安装流程：更新并安装 UFW 与 Fail2Ban"
  export DEBIAN_FRONTEND=noninteractive

  info "apt-get update && apt-get upgrade -y"
  apt-get update -y
  apt-get upgrade -y

  info "正在安装 UFW..."
  apt-get install -y ufw
  info "UFW 安装完成（或已存在）"

  info "正在安装 Fail2Ban..."
  apt-get install -y fail2ban
  info "Fail2Ban 安装完成（或已存在）"

  info "确保 UFW 允许 SSH ${SSH_PORT}/tcp（避免被锁死）"
  ufw allow "${SSH_PORT}/tcp" || warn "ufw allow 返回非零（若 ufw 未启用这是正常的）"

  # —— 关键：设置 UFW 默认为允许所有传入（因为你要用 UFW 仅配合 fail2ban）
  info "将 UFW 设置为允许所有传入连接（UFW 仅用于配合 Fail2Ban 封禁）"
  ufw default allow incoming || warn "设置 ufw default allow incoming 返回非零"
  ufw default allow outgoing || true

  # 再次确认放行 SSH（冗余安全）
  ufw allow "${SSH_PORT}/tcp" || true

  # 重启/启用 ufw
  ufw --force enable || warn "启用 UFW 返回非零"
  if systemctl list-units --type=service --all | grep -q '^ufw\.service'; then
    systemctl restart ufw || warn "重启 ufw 返回非零"
  fi

  SSH_LOGPATH="$(detect_ssh_logpath)"
  info "使用 SSH 日志路径：${SSH_LOGPATH}"

  info "写入 Fail2Ban 配置（覆盖）：${JAIL_FILE}"
  mkdir -p "${JAIL_DIR}"
  cat > "${JAIL_FILE}" <<EOF
[${JAIL}]
enabled = true
port    = ${SSH_PORT}
filter  = sshd
logpath = ${SSH_LOGPATH}
ignoreip = 127.0.0.1/8 ::1
maxretry = 5
findtime = 300
bantime  = ${BANTIME}
banaction = ufw
EOF
  chmod 644 "${JAIL_FILE}"
  info "配置已写入：${JAIL_FILE}"

  info "重启 fail2ban 服务"
  systemctl restart fail2ban || warn "重启 fail2ban 返回非零"

  # 添加定期清理任务
  setup_periodic_log_clear

  echo -e "${SEP}"
  info "安装与配置已完成，显示 fail2ban 服务状态："
  systemctl status fail2ban --no-pager -l || true
  echo -e "${SEP}"
}

show_status(){
  echo -e "${SEP}"
  info "fail2ban 服务状态："
  systemctl status fail2ban --no-pager -l || true
  echo -e "${SEP}"
}

show_config(){
  echo -e "${SEP}"
  if [ -f "${JAIL_FILE}" ]; then
    info "显示 ${JAIL_FILE} 内容："
    sed -n '1,200p' "${JAIL_FILE}" || true
  else
    warn "${JAIL_FILE} 未找到。"
    if [ -d "/etc/fail2ban" ]; then
      info "/etc/fail2ban 下的文件："
      ls -la /etc/fail2ban || true
    fi
  fi
  echo -e "${SEP}"
}

show_logs(){
  if [ ! -f "${FAIL2BAN_LOG}" ]; then
    warn "${FAIL2BAN_LOG} 不存在，检查 Fail2Ban 是否在写日志。"
    press_any
    return
  fi
  info "开始 tail -n 50 -F ${FAIL2BAN_LOG}（按 Ctrl+C 返回菜单）"
  echo -e "${SEP}"
  trap 'info "停止日志查看，返回菜单"; trap - INT; return 0' INT
  tail -n 50 -F "${FAIL2BAN_LOG}" || true
  trap - INT
  echo -e "${SEP}"
}

show_bans(){
  echo -e "${SEP}"
  if ! systemctl is-active --quiet fail2ban; then
    warn "fail2ban 未运行。"
    echo -e "${SEP}"
    return
  fi

  # 试图使用带时间的输出（新版 fail2ban 支持 --with-time）
  BANS_RAW="$(fail2ban-client get ${JAIL} banip --with-time 2>/dev/null || true)"

  declare -A BAN_MAP
  if [ -n "${BANS_RAW}" ]; then
    info "当前封禁列表："
    IFS=$'\n'
    i=1
    for line in ${BANS_RAW}; do
      ip=$(printf "%s" "${line}" | awk '{print $1}')
      t=$(printf "%s" "${line}" | cut -d' ' -f2-)
      printf " %2d) %-15s      Ban  %s\n" "${i}" "${ip}" "${t}"
      BAN_MAP[$i]="${ip}"
      ((i++))
    done
    unset IFS
  else
    # 回退：不带时间的封禁列表
    BANS_LINE="$(fail2ban-client status ${JAIL} 2>/dev/null | sed -n 's/.*Banned IP list:\s*//p' || true)"
    if [ -z "${BANS_LINE}" ]; then
      info "当前没有被封禁的 IP。"
      echo -e "${SEP}"
      return
    fi
    info "当前封禁列表（不含时间）："
    i=1
    for ip in ${BANS_LINE}; do
      printf " %2d) %-15s      Ban  N/A\n" "${i}" "${ip}"
      BAN_MAP[$i]="${ip}"
      ((i++))
    done
  fi

  echo
  read -r -p "输入序号解除封禁 (0 返回菜单): " UNBAN_CHOICE
  if [ "${UNBAN_CHOICE}" = "0" ]; then
    echo -e "${SEP}"
    return
  elif [[ -n "${BAN_MAP[$UNBAN_CHOICE]:-}" ]]; then
    ip="${BAN_MAP[$UNBAN_CHOICE]}"
    info "正在解除封禁 IP: ${ip}"
    fail2ban-client set ${JAIL} unbanip "${ip}" || warn "解除封禁失败"
  else
    warn "无效序号"
  fi
  echo -e "${SEP}"
}

uninstall_fail2ban(){
  echo -e "${SEP}"
  warn "你即将卸载 Fail2Ban 并清理配置与日志。此操作不可撤销。"
  # 修复显示问题：先用 printf 输出带颜色提示，再 read
  printf "确认卸载？请输入 ${YELLOW}[Y/n]${RESET} （默认 N，即取消）: "
  read -r CONF
  case "${CONF:-n}" in
    [Yy])
      info "确认：开始卸载并清理..."
      systemctl stop fail2ban || true
      apt-get purge -y fail2ban || true
      apt-get autoremove -y || true
      apt-get autoclean -y || true

      info "清理配置和日志"
      rm -rf /etc/fail2ban
      rm -f "${FAIL2BAN_LOG}"

      if [ -f "${CLEAR_SCRIPT}" ]; then
        rm -f "${CLEAR_SCRIPT}"
        info "已删除 ${CLEAR_SCRIPT}"
      fi

      OLD_CRON="$(crontab -l 2>/dev/null || true)"
      if [ -n "${OLD_CRON}" ]; then
        NEW_CRON="$(printf "%s\n" "${OLD_CRON}" | awk -v m="${CRON_MARK}" -v l="${CRON_LINE}" '$0!=m && $0!=l')"
        printf "%s\n" "${NEW_CRON}" | crontab - 2>/dev/null || true
        info "已从 crontab 中移除定时清理任务（如存在）"
      fi

      systemctl daemon-reload || true
      info "卸载并清理完成。"
      ;;
    *)
      info "已取消卸载操作。"
      ;;
  esac
  echo -e "${SEP}"
}

# 主循环
while true; do
  echo -e "${SEP}"
  show_install_status
  echo -e "${SEP}\n"

  printf "${CYAN}请选择操作：${RESET}\n"
  printf " ${GREEN}1)${RESET} 安装并配置 Fail2Ban（并设置每15天清空日志）\n"
  printf " ${GREEN}2)${RESET} 查看 fail2ban 服务状态\n"
  printf " ${GREEN}3)${RESET} 查看 fail2ban 配置文件\n"
  printf " ${GREEN}4)${RESET} 查看实时日志\n"
  printf " ${GREEN}5)${RESET} 查看封禁情况并可解除封禁\n"
  printf " ${GREEN}6)${RESET} 卸载 Fail2Ban（含配置与日志，需确认 Y/y 才卸载）\n"
  printf " ${GREEN}0)${RESET} 退出\n\n"

  read -r -p "$(printf "${YELLOW}输入选项 [0-6]: ${RESET}")" CHOICE

  case "${CHOICE}" in
    1) echo -e "${SEP}"; install_fail2ban; press_any ;;
    2) echo -e "${SEP}"; show_status; press_any ;;
    3) echo -e "${SEP}"; show_config; press_any ;;
    4) echo -e "${SEP}"; show_logs; press_any ;;
    5) echo -e "${SEP}"; show_bans; press_any ;;
    6) echo -e "${SEP}"; uninstall_fail2ban; press_any ;;
    0) info "退出脚本"; exit 0 ;;
    *) warn "无效选项，请重新选择"; press_any ;;
  esac
done
