#!/usr/bin/env bash
# ==============================================================================
# sysaudit.sh - read-only Linux server health & hardening audit
#
# Capstone project of the Sysadmin phase (Days 01-10 of my tools-journal).
# It READS state and writes a Markdown report. It never changes firewall rules,
# services, files, users or packages.
#
# Usage:  sudo ./sysaudit.sh [--out FILE] [--strict]
#         ./sysaudit.sh --help
# ==============================================================================

VERSION="1.0"
PATH="$PATH:/usr/sbin:/sbin:/usr/local/sbin"

# --- thresholds (edit these to taste) -----------------------------------------
DISK_WARN=85          # warn when a filesystem (space or inodes) is this % full
UPDATES_WARN=50       # warn when this many apt updates are pending
BIGLOG_MB=100         # warn about any single file in /var/log bigger than this
DELETED_MIN_MB=1      # only count deleted-but-open files at least this big (tiny ones are normal desktop noise)

OUT=""
STRICT=0
DELETED_MIN_BYTES=$((DELETED_MIN_MB * 1048576))

usage() {
  cat <<EOF
sysaudit $VERSION - read-only Linux server health & hardening audit

Usage: sysaudit.sh [options]

Options:
  -o, --out FILE   write the Markdown report to FILE
                   (default: ./reports/sysaudit-<host>-<date>.md)
      --strict     exit with status 1 if any check ends in WARN
  -h, --help       show this help
  -v, --version    show the version

Run it with sudo for the full audit. Without root, checks that need root
(firewall rules, sshd config, fail2ban/auditd details, shadow file) are skipped.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out)
      if [ -z "${2:-}" ]; then echo "Option $1 needs a file name." >&2; exit 2; fi
      OUT="$2"; shift 2 ;;
    --strict)     STRICT=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    -v|--version) echo "sysaudit $VERSION"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

IS_ROOT=0
[ "$(id -u)" -eq 0 ] && IS_ROOT=1

if [ -z "$OUT" ]; then
  OUT="./reports/sysaudit-$(hostname)-$(date +%Y%m%d-%H%M).md"
fi
mkdir -p "$(dirname "$OUT")" 2>/dev/null || { echo "Cannot create folder for $OUT" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DETAIL="$TMP/detail.md"
ROWS="$TMP/rows.md"
: > "$DETAIL"
: > "$ROWS"

n_ok=0; n_warn=0; n_info=0; n_skip=0

# --- helpers -------------------------------------------------------------------
have()  { command -v "$1" >/dev/null 2>&1; }
say()   { printf '%s\n' "$*" >> "$DETAIL"; }
h()     { say ""; say "## $1"; say ""; }
block() { say '```'; cat >> "$DETAIL"; say '```'; say ""; }   # usage: cmd | block

# row AREA STATUS NOTE   (STATUS: OK | WARN | INFO | SKIP)
row() {
  local label
  case "$2" in
    OK)   label="✅ OK";   n_ok=$((n_ok + 1)) ;;
    WARN) label="⚠️ WARN"; n_warn=$((n_warn + 1)) ;;
    INFO) label="ℹ️ INFO"; n_info=$((n_info + 1)) ;;
    *)    label="⏭️ SKIP"; n_skip=$((n_skip + 1)) ;;
  esac
  printf '| %s | %s | %s |\n' "$1" "$label" "$3" >> "$ROWS"
}

need_root_note() { say "_Skipped: needs root. Re-run with \`sudo\` for this check._"; say ""; }

# --- 1. system -----------------------------------------------------------------
check_system() {
  h "1. System"
  {
    echo "Host:    $(hostname)"
    echo "OS:      $( ( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}" ) || echo unknown )"
    echo "Kernel:  $(uname -r)"
    echo "Uptime:  $(uptime -p 2>/dev/null || uptime)"
    echo "Run as:  $(id -un) (root: $([ "$IS_ROOT" -eq 1 ] && echo yes || echo no))"
    echo "Date:    $(date '+%Y-%m-%d %H:%M:%S %Z')"
  } | block
}

# --- 2. exposed ports (Day 02: lsof / ss) ------------------------------------------
check_ports() {
  h "2. Exposed ports (Day 02)"
  if ! have ss; then
    say "ss is not installed."; say ""
    row "Exposed ports" SKIP "ss not installed"
    return
  fi

  local sockets exposed total n_exposed n_local risky
  sockets=$(ss -tuln 2>/dev/null | awk 'NR>1 {print $1, $5}')
  exposed=$(printf '%s\n' "$sockets" | awk 'NF==2 { a=$2; if (a ~ /^127\./ || a ~ /^\[?::1\]?:/) next; print }')
  total=$(printf '%s\n' "$sockets" | sed '/^$/d' | sort -u | wc -l)
  n_exposed=$(printf '%s\n' "$exposed" | sed '/^$/d' | sort -u | wc -l)
  n_local=$((total - n_exposed))

  {
    echo "Listening beyond localhost (proto  local-address:port; the firewall may still block these):"
    if [ "$n_exposed" -gt 0 ]; then printf '%s\n' "$exposed" | sort -u; else echo "(none)"; fi
    echo
    echo "Local-only sockets (127.0.0.1 / ::1): $n_local"
  } | block

  if [ "$IS_ROOT" -eq 1 ]; then
    say "Owning programs (\`ss -tulnp\`; Docker-published ports show as docker-proxy):"
    ss -tulnp 2>/dev/null | head -40 | block
  fi

  risky=$(printf '%s\n' "$exposed" | awk 'NF==2 {p=$2; sub(/.*:/,"",p); print p}' | sort -un | awk '
    BEGIN { n = split("21 23 69 111 135 139 445 1433 2375 3306 3389 5432 5900 6379 9200 11211 27017", r, " ")
            for (i = 1; i <= n; i++) R[r[i]] = 1 }
    ($1 in R) { printf "%s ", $1 }')

  risky=$(echo $risky)
  if [ -n "$risky" ]; then
    row "Exposed ports" WARN "risky service port(s) listening beyond localhost: ${risky}"
  elif [ "$n_exposed" -gt 0 ]; then
    row "Exposed ports" INFO "$n_exposed socket(s) listening beyond localhost, review the list (the firewall may still block them)"
  else
    row "Exposed ports" OK "nothing listens beyond localhost"
  fi
}

# --- 3. firewall (Days 04-05), read only -------------------------------------------
check_firewall() {
  h "3. Firewall (Days 04-05) - read only"
  if [ "$IS_ROOT" -ne 1 ]; then
    need_root_note
    row "Firewall" SKIP "needs root"
    return
  fi

  local ufw_active=0 policy="" rules=0
  if have ufw; then
    ufw status verbose 2>&1 | block
    ufw status 2>/dev/null | grep -q '^Status: active' && ufw_active=1
  fi
  if have iptables; then
    policy=$(iptables -S INPUT 2>/dev/null | awk '/^-P INPUT/ {print $3}')
    rules=$(iptables -S 2>/dev/null | grep -c '^-A')
    say "iptables INPUT default policy: ${policy:-unknown}; rules in total: $rules"
    say ""
  fi
  if have nft && [ -z "$policy" ]; then
    nft list ruleset 2>/dev/null | head -30 | block
  fi

  if ! have ufw && ! have iptables && ! have nft; then
    say "No ufw, iptables or nft command found."; say ""
  fi

  if [ "$ufw_active" -eq 1 ]; then
    row "Firewall" OK "ufw is active (iptables INPUT policy: ${policy:-n/a})"
  elif [ "$policy" = "DROP" ] || [ "$policy" = "REJECT" ]; then
    row "Firewall" OK "iptables INPUT policy $policy, $rules rule(s)"
  elif [ "$policy" = "ACCEPT" ]; then
    row "Firewall" WARN "iptables INPUT policy is ACCEPT ($rules rule(s)); anything not blocked by a rule gets through"
  elif have nft; then
    row "Firewall" INFO "nftables present, review 'nft list ruleset'"
  else
    row "Firewall" WARN "no ufw, iptables or nftables found"
  fi
}

# --- 4. ssh daemon -----------------------------------------------------------------
check_ssh() {
  h "4. SSH daemon"
  if ! have sshd; then
    say "sshd is not installed."; say ""
    row "SSH" INFO "sshd not installed"
    return
  fi
  local state
  state=$(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)
  say "Service state: ${state:-unknown}"
  say ""

  if [ "$IS_ROOT" -ne 1 ]; then
    need_root_note
    row "SSH" SKIP "needs root (sshd -T); service: ${state:-unknown}"
    return
  fi

  local cfg root pw empty port notes="" sshd_err="$TMP/sshd.err"
  cfg=$(sshd -T 2>"$sshd_err")
  local keys
  keys=$(printf '%s\n' "$cfg" | grep -iE '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|x11forwarding|usepam) ')
  if [ -n "$keys" ]; then printf '%s\n' "$keys" | block; fi

  # sshd -T prints lowercase keys on some versions and CamelCase (Port, UsePAM) on others, so compare in lowercase
  root=$(printf '%s\n' "$cfg"  | awk 'tolower($1)=="permitrootlogin" {print tolower($2); exit}')
  pw=$(printf '%s\n' "$cfg"    | awk 'tolower($1)=="passwordauthentication" {print tolower($2); exit}')
  empty=$(printf '%s\n' "$cfg" | awk 'tolower($1)=="permitemptypasswords" {print tolower($2); exit}')
  port=$(printf '%s\n' "$cfg"  | awk 'tolower($1)=="port" {print $2; exit}')

  if [ -z "$port" ]; then
    say "sshd -T gave no usable settings. First lines of its output and errors:"
    { [ -n "$cfg" ] && printf '%s\n' "$cfg" | head -5; head -5 "$sshd_err" 2>/dev/null; echo "(exit status of sshd -T may be non-zero)"; } | block
    row "SSH" INFO "could not read settings from sshd -T (try: sudo sshd -T | head)"
    return
  fi

  [ "$root" = "yes" ]  && notes="$notes root login allowed;"
  [ "$empty" = "yes" ] && notes="$notes empty passwords allowed;"
  [ "$pw" = "yes" ]    && notes="$notes password logins enabled (keys + fail2ban recommended);"

  notes="${notes# }"; notes="${notes%;}"
  if [ -z "$notes" ] && [ -z "$root" ] && [ -z "$pw" ]; then
    row "SSH" INFO "port ${port}: root-login and password settings not listed by sshd -T (defaults apply; check /etc/ssh/sshd_config)"
  elif [ -n "$notes" ]; then
    row "SSH" WARN "port ${port:-?}: ${notes}"
  elif [ -z "$cfg" ]; then
    row "SSH" INFO "could not read the sshd configuration"
  else
    row "SSH" OK "port ${port:-?}, root login: ${root:-?}, password logins: ${pw:-?}"
  fi
}

# --- 5. fail2ban (Day 06) ------------------------------------------------------------
check_fail2ban() {
  h "5. Brute-force defense - fail2ban (Day 06)"
  if ! have fail2ban-client; then
    say "fail2ban is not installed."; say ""
    row "Brute-force defense" WARN "fail2ban not installed"
    return
  fi
  local state
  state=$(systemctl is-active fail2ban 2>/dev/null)
  say "Service state: ${state:-unknown}"
  say ""
  if [ "$state" != "active" ]; then
    row "Brute-force defense" WARN "fail2ban installed but ${state:-not running} (sudo systemctl enable --now fail2ban)"
    return
  fi
  if [ "$IS_ROOT" -ne 1 ]; then
    need_root_note
    row "Brute-force defense" INFO "fail2ban active (run with sudo for jail details)"
    return
  fi

  fail2ban-client status 2>&1 | block
  local jails j banned total_banned=0 n_jails=0
  jails=$(fail2ban-client status 2>/dev/null | sed -n 's/.*Jail list:[[:space:]]*//p' | tr -d ',')
  for j in $jails; do
    n_jails=$((n_jails + 1))
    fail2ban-client status "$j" 2>/dev/null | grep -E 'Currently (failed|banned)|Total (failed|banned)|Banned IP' | sed -E 's/^[ |`-]+//' | sed "s/^/[$j] /" | block
    banned=$(fail2ban-client status "$j" 2>/dev/null | awk -F: '/Currently banned/ {gsub(/[ \t]/,"",$2); print $2}')
    total_banned=$((total_banned + ${banned:-0}))
  done

  if [ "$n_jails" -eq 0 ]; then
    row "Brute-force defense" WARN "fail2ban is running but no jail is enabled"
  else
    row "Brute-force defense" OK "active, $n_jails jail(s): $(echo $jails); currently banned: $total_banned"
  fi
}

# --- 6. auditd (Day 08) --------------------------------------------------------------
check_auditd() {
  h "6. Audit trail - auditd (Day 08)"
  if ! have auditctl; then
    say "auditd is not installed."; say ""
    row "Audit trail" WARN "auditd not installed"
    return
  fi
  local state
  state=$(systemctl is-active auditd 2>/dev/null)
  say "Service state: ${state:-unknown}"
  say ""
  if [ "$state" != "active" ]; then
    row "Audit trail" WARN "auditd installed but ${state:-not running} (sudo systemctl enable --now auditd)"
    return
  fi
  if [ "$IS_ROOT" -ne 1 ]; then
    need_root_note
    row "Audit trail" INFO "auditd active (run with sudo for rule count)"
    return
  fi

  auditctl -s 2>/dev/null | block
  local rules enabled
  rules=$(auditctl -l 2>/dev/null | grep -vc '^No rules')
  enabled=$(auditctl -s 2>/dev/null | awk '/^enabled/ {print $2}')
  say "Active audit rules:"
  auditctl -l 2>/dev/null | head -20 | block

  if [ "${rules:-0}" -eq 0 ]; then
    row "Audit trail" WARN "auditd running but no rules loaded, nothing is being watched"
  elif [ "$enabled" = "2" ]; then
    row "Audit trail" INFO "$rules rule(s), configuration is locked (enabled 2), a reboot is needed to change it"
  else
    row "Audit trail" OK "auditd active with $rules rule(s)"
  fi
}

# --- 7. logrotate (Day 07) ------------------------------------------------------------
check_logrotate() {
  h "7. Log retention - logrotate (Day 07)"
  if ! have logrotate; then
    say "logrotate is not installed."; say ""
    row "Log retention" WARN "logrotate not installed"
    return
  fi
  local n_cfg scheduled="no" errs=0 biglogs
  n_cfg=$(ls /etc/logrotate.d 2>/dev/null | wc -l)
  if systemctl is-enabled logrotate.timer >/dev/null 2>&1 || [ -x /etc/cron.daily/logrotate ]; then
    scheduled="yes"
  fi
  say "Service configs in /etc/logrotate.d: $n_cfg"
  say "Runs automatically (timer or cron.daily): $scheduled"
  say ""

  if [ "$IS_ROOT" -eq 1 ]; then
    errs=$(logrotate -d /etc/logrotate.conf 2>&1 | grep -ic '^error')
    say "Dry run of the whole config (logrotate -d), lines starting with 'error': $errs"
    logrotate -d /etc/logrotate.conf 2>&1 | grep -i '^error' | head -5 | block
  fi

  biglogs=$(find /var/log -xdev -type f -size +"${BIGLOG_MB}"M 2>/dev/null)
  if [ -n "$biglogs" ]; then
    say "Log files over ${BIGLOG_MB} MB:"
    printf '%s\n' "$biglogs" | head -10 | while read -r f; do ls -lh "$f"; done | block
  fi

  if [ -n "$biglogs" ]; then
    row "Log retention" WARN "log file(s) over ${BIGLOG_MB} MB in /var/log, check their rotation rules"
  elif [ "$scheduled" != "yes" ]; then
    row "Log retention" WARN "logrotate is installed but has no daily timer/cron job"
  elif [ "${errs:-0}" -gt 0 ]; then
    row "Log retention" WARN "logrotate dry run reports $errs error line(s)"
  else
    if [ "$IS_ROOT" -eq 1 ]; then
      row "Log retention" OK "$n_cfg config(s), scheduled daily, no big logs, dry run clean"
    else
      row "Log retention" OK "$n_cfg config(s), scheduled daily, no big logs (dry run skipped: needs root)"
    fi
  fi
}

# --- 8. disk (Days 02, 07, 09) ---------------------------------------------------------
check_disk() {
  h "8. Disk health (Days 02, 07, 09)"
  local dfx="-x tmpfs -x devtmpfs -x squashfs -x overlay"
  df -hP $dfx 2>/dev/null | block

  local worst_space worst_inode deleted_open="" n_deleted=0
  worst_space=$(df -P $dfx 2>/dev/null | awk 'NR>1 {gsub("%","",$5); if ($5+0 > m) {m=$5+0; fs=$6}} END {print m+0 ":" fs}')
  worst_inode=$(df -iP $dfx 2>/dev/null | awk 'NR>1 && $5 ~ /%/ {gsub("%","",$5); if ($5+0 > m) {m=$5+0; fs=$6}} END {print m+0 ":" fs}')

  say "Biggest items in /var/log (like ncdu, one level of detail):"
  du -ah /var/log 2>/dev/null | sort -rh | head -6 | block

  if have lsof && [ "$IS_ROOT" -eq 1 ]; then
    local all_deleted n_all
    all_deleted=$(lsof +L1 2>/dev/null | awk 'NR>1')
    n_all=$(printf '%s\n' "$all_deleted" | sed '/^$/d' | wc -l)
    deleted_open=$(printf '%s\n' "$all_deleted" | awk -v min="$DELETED_MIN_BYTES" '$5=="REG" && $7+0 >= min && $0 !~ /\/memfd:/')
    n_deleted=$(printf '%s\n' "$deleted_open" | sed '/^$/d' | wc -l)
    say "Deleted-but-still-open files (lsof +L1), the Day 02 trap: $n_all in total, $n_deleted of them at least ${DELETED_MIN_MB} MB (memfd and tiny desktop files are ignored)"
    if [ "$n_deleted" -gt 0 ]; then printf '%s\n' "$deleted_open" | head -10 | block; fi
  fi

  local sp_pct="${worst_space%%:*}" sp_fs="${worst_space#*:}"
  local in_pct="${worst_inode%%:*}" in_fs="${worst_inode#*:}"
  local note="fullest filesystem: ${sp_pct}% (${sp_fs}), inodes: ${in_pct}% (${in_fs})"

  if [ "${sp_pct:-0}" -ge "$DISK_WARN" ] || [ "${in_pct:-0}" -ge "$DISK_WARN" ]; then
    row "Disk health" WARN "$note, at or above the ${DISK_WARN}% threshold"
  elif [ "$n_deleted" -gt 0 ]; then
    row "Disk health" WARN "$note; $n_deleted deleted-but-open file(s) of ${DELETED_MIN_MB} MB or more holding space (sudo lsof +L1)"
  else
    row "Disk health" OK "$note"
  fi
}

# --- 9. accounts ------------------------------------------------------------------------
check_accounts() {
  h "9. Accounts"
  local uid0 empty="" notes="" g
  uid0=$(awk -F: '$3==0 && $1!="root" {print $1}' /etc/passwd 2>/dev/null)
  say "Accounts with UID 0 other than root: ${uid0:-none}"
  say ""

  if [ "$IS_ROOT" -eq 1 ] && [ -r /etc/shadow ]; then
    empty=$(awk -F: '$2=="" {print $1}' /etc/shadow 2>/dev/null)
    say "Accounts with an empty password: ${empty:-none}"
    say ""
  fi

  for g in sudo wheel admin; do
    if getent group "$g" >/dev/null 2>&1; then
      say "Members of group '$g': $(getent group "$g" | cut -d: -f4)"
    fi
  done
  say ""

  [ -n "$uid0" ]  && notes="$notes extra UID 0 account(s): $(echo $uid0);"
  [ -n "$empty" ] && notes="$notes empty password: $(echo $empty);"

  if [ -n "$notes" ]; then
    row "Accounts" WARN "$notes"
  elif [ "$IS_ROOT" -eq 1 ]; then
    row "Accounts" OK "no extra UID 0 accounts, no empty passwords"
  else
    row "Accounts" INFO "no extra UID 0 accounts (empty-password check needs root)"
  fi
}

# --- 10. updates ---------------------------------------------------------------------------
check_updates() {
  h "10. Pending updates"
  if ! have apt; then
    say "apt not available."; say ""
    row "Updates" SKIP "not an apt-based system"
    return
  fi
  local n
  n=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable')
  say "Packages with a newer version available (based on the last 'apt update'): $n"
  say ""
  if [ "${n:-0}" -ge "$UPDATES_WARN" ]; then
    row "Updates" WARN "$n pending update(s), at or above the $UPDATES_WARN threshold"
  else
    row "Updates" OK "$n pending update(s)"
  fi
}

# --- 11. failed services ------------------------------------------------------------------------
check_services() {
  h "11. Failed services"
  if ! have systemctl || ! systemctl list-units >/dev/null 2>&1; then
    say "systemd is not available."; say ""
    row "Services" SKIP "systemd not available"
    return
  fi
  local failed n
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
  n=$(printf '%s\n' "$failed" | sed '/^$/d' | wc -l)
  if [ "$n" -gt 0 ]; then
    printf '%s\n' "$failed" | block
    row "Services" WARN "$n failed unit(s): $(echo $failed)"
  else
    say "No failed units."; say ""
    row "Services" OK "no failed units"
  fi
}

# --- run everything ---------------------------------------------------------------------------------
check_system
check_ports
check_firewall
check_ssh
check_fail2ban
check_auditd
check_logrotate
check_disk
check_accounts
check_updates
check_services

{
  echo "# 🛡️ Sysadmin Audit Report"
  echo
  echo "> Generated by \`sysaudit.sh\` v$VERSION on **$(hostname)** at $(date '+%Y-%m-%d %H:%M:%S'). Read-only: nothing on this machine was changed."
  echo
  echo "## Scorecard"
  echo
  echo "| Area | Status | Note |"
  echo "| --- | --- | --- |"
  cat "$ROWS"
  echo
  echo "**Summary:** $n_ok OK · $n_warn warning(s) · $n_info info · $n_skip skipped"
  if [ "$IS_ROOT" -ne 1 ]; then
    echo
    echo "> Not run as root, so some checks were skipped. Re-run with \`sudo ./sysaudit.sh\` for the full audit."
  fi
  cat "$DETAIL"
  echo "---"
  echo "_End of report._"
} > "$OUT"

cat "$OUT"
echo
echo "Report saved to: $OUT"

if [ "$STRICT" -eq 1 ] && [ "$n_warn" -gt 0 ]; then
  exit 1
fi
exit 0
