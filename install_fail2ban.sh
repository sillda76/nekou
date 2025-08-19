#!/usr/bin/env bash
# install_fail2ban.sh - Debian/Ubuntu 交互脚本
# 包含：忽略本地地址、每15天清空日志、封禁管理、卸载时删除 cron 任务
set -euo pipefail

# 颜色变量（使用 \033，更稳健）
RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"
BLUE="\033[34m"; CYAN="\033[36m"; BOLD="\033[1m"; RESET="\033[0m"

info(){ printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
warn(){ printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
err(){ printf "${RED}[ERROR]${RESET} %s\n" "$*\n" >&2; exit 1; }

if [ "$EUID" -ne 0 ]; then
  err "请以 root 或 sudo 运行：sudo bash $0"
fi

SSH_PORT=22
JAIL="sshd"
JAIL_DIR="/etc/fail2ban/jail.d"
JAIL_FILE="${JAIL_DIR}/sshd-ufw.local"
LOG_FILE="/var/log/fail2ban.log"
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
  info "已创建 ${CLEAR_SCRIPT}"

  CRONTAB_CONTENT="$(crontab -l 2>/dev/null || true)"
  if printf "%s\n" "$CRONTAB_CONTENT" | grep -Fq "${CRON_MARK}"; then
    info "定时任务已存在，跳过添加"
  else
    {
      printf "%s\n" "$CRONTAB_CONTENT"
      printf "%s\n" "${CRON_MARK}"
      printf "%s\n" "${CRON_LINE}"
    } | crontab -
    info "已添加 crontab 任务：${CRON_LINE}"
  fi
}

install_fail2ban(){
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y && apt-get upgrade -y
  apt-get install -y ufw fail2ban

  ufw allow "${SSH_PORT}/tcp" || true

  mkdir -p "${JAIL_DIR}"
  cat > "${JAIL_FILE}" <<EOF
[${JAIL}]
enabled = true
port    = ${SSH_PORT}
filter  = sshd
logpath = %(sshd_log)s
ignoreip = 127.0.0.1/8 ::1
maxretry = 5
findtime = 300
bantime  = 600
banaction = ufw
EOF

  systemctl restart fail2ban
  ufw --force enable
  systemctl restart ufw || true

  setup_periodic_log_clear
  echo -e "${SEP}"
  systemctl status fail2ban --no-pager -l || true
  echo -e "${SEP}"
}

show_status(){ systemctl status fail2ban --no-pager -l || true; }

show_config(){
  echo -e "${SEP}"
  if [ -f "${JAIL_FILE}" ]; then
    cat "${JAIL_FILE}"
  else
    warn "配置文件不存在"
  fi
  echo -e "${SEP}"
}

show_logs(){
  if [ ! -f "${LOG_FILE}" ]; then
    warn "日志文件不存在"
    return
  fi
  tail -n 50 -F "${LOG_FILE}"
}

show_bans(){
  echo -e "${SEP}"
  if ! systemctl is-active --quiet fail2ban; then
    warn "fail2ban 未运行"
    return
  fi

  BANS_RAW=$(fail2ban-client get ${JAIL} banip --with-time 2>/dev/null || true)
  declare -A BAN_MAP
  if [ -n "$BANS_RAW" ]; then
    i=1
    echo -e "${GREEN}当前封禁:${RESET}"
    while read -r line; do
      ip=$(echo "$line" | awk '{print $1}')
      t=$(echo "$line" | cut -d' ' -f2-)
      printf "%2d) %s  %s\n" "$i" "$ip" "$t"
      BAN_MAP[$i]=$ip
      ((i++))
    done <<< "$BANS_RAW"
  else
    BANS_LINE=$(fail2ban-client status ${JAIL} | sed -n 's/.*Banned IP list:\s*//p')
    [ -z "$BANS_LINE" ] && { info "无封禁 IP"; return; }
    i=1
    for ip in $BANS_LINE; do
      printf "%2d) %s\n" "$i" "$ip"
      BAN_MAP[$i]=$ip
      ((i++))
    done
  fi

  echo
  read -r -p "输入序号解除封禁 (0 返回): " CH
  if [ "$CH" != "0" ] && [ -n "${BAN_MAP[$CH]:-}" ]; then
    fail2ban-client set ${JAIL} unbanip "${BAN_MAP[$CH]}"
    info "已解除封禁 ${BAN_MAP[$CH]}"
  fi
  echo -e "${SEP}"
}

uninstall_fail2ban(){
  echo -e "${SEP}"
  read -r -p "确认卸载 Fail2Ban？ [Y/n]: " CONF
  case "${CONF:-n}" in
    [Yy])
      systemctl stop fail2ban || true
      apt-get purge -y fail2ban
      rm -rf /etc/fail2ban
      rm -f "${LOG_FILE}" "${CLEAR_SCRIPT}"
      OLD_CRON="$(crontab -l 2>/dev/null || true)"
      NEW_CRON="$(printf "%s\n" "${OLD_CRON}" | awk -v m="${CRON_MARK}" -v l="${CRON_LINE}" '$0!=m && $0!=l')"
      printf "%s\n" "${NEW_CRON}" | crontab - || true
      info "已卸载并清理"
      ;;
    *) info "取消卸载" ;;
  esac
  echo -e "${SEP}"
}

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

  case "$CHOICE" in
    1) install_fail2ban; press_any ;;
    2) show_status; press_any ;;
    3) show_config; press_any ;;
    4) show_logs; press_any ;;
    5) show_bans; press_any ;;
    6) uninstall_fail2ban; press_any ;;
    0) exit 0 ;;
    *) warn "无效选项"; press_any ;;
  esac
done
