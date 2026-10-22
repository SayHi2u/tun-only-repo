#!/system/bin/sh
# 按包名解析当前 UID，并只允许这些 UID 从 $TUN_IF 出站。
# 物理网卡、移动数据、其他 tun 接口一律 REJECT。
# 由 service.sh 开机调用；也可在 Termux 中手动执行。

MODDIR=${0%/*}
PATH=/system/bin:/system/xbin:/sbin:$PATH
export PATH
CONF="$MODDIR/packages.conf"
STATE="$MODDIR/uids.state"
LOG="$MODDIR/apply.log"
CHAIN4="TUN_ONLY_APPS"
CHAIN6="TUN_ONLY_APPS6"

# 读取接口名配置
[ -f "$MODDIR/config.conf" ] && . "$MODDIR/config.conf"
TUN_IF="${TUN_IF:-tun0}"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

if ! command -v iptables >/dev/null 2>&1; then
  log "ERROR: iptables not found in PATH=$PATH"
  exit 1
fi

# 清理上一次记录的 UID 引用，避免卸载重装后旧 UID 残留、误伤复用 UID 的其他 app
if [ -f "$STATE" ]; then
  for old in $(cat "$STATE"); do
    while iptables -D OUTPUT -m owner --uid-owner "$old" -j "$CHAIN4" 2>/dev/null; do :; done
    while ip6tables -D OUTPUT -m owner --uid-owner "$old" -j "$CHAIN6" 2>/dev/null; do :; done
  done
fi

# IPv4：只允许 loopback 和指定 tun
iptables -N "$CHAIN4" 2>/dev/null
iptables -F "$CHAIN4" 2>/dev/null
iptables -A "$CHAIN4" -o lo -j ACCEPT
iptables -A "$CHAIN4" -o "$TUN_IF" -j ACCEPT
iptables -A "$CHAIN4" -j REJECT

# IPv6：同样只允许 loopback 和指定 tun
if command -v ip6tables >/dev/null 2>&1; then
  ip6tables -N "$CHAIN6" 2>/dev/null
  ip6tables -F "$CHAIN6" 2>/dev/null
  ip6tables -A "$CHAIN6" -o lo -j ACCEPT
  ip6tables -A "$CHAIN6" -o "$TUN_IF" -j ACCEPT
  ip6tables -A "$CHAIN6" -j REJECT
else
  log "WARN: ip6tables not found; IPv6 is not covered"
fi

NEW=""

if [ ! -f "$CONF" ]; then
  log "ERROR: missing $CONF"
  echo "" > "$STATE"
  exit 1
fi

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  case "$pkg" in
    \#*) continue ;;
  esac

  # 优先取所有用户/工作资料下的 UID；失败则退回当前用户
  UIDS=$(/system/bin/cmd package list packages -U --user all 2>/dev/null \
    | awk -v p="package:${pkg}" '$1 == p { sub(/^uid:/, "", $2); print $2 }')
  if [ -z "$UIDS" ]; then
    UIDS=$(/system/bin/cmd package list packages -U 2>/dev/null \
      | awk -v p="package:${pkg}" '$1 == p { sub(/^uid:/, "", $2); print $2 }')
  fi

  if [ -z "$UIDS" ]; then
    log "not installed: $pkg"
    continue
  fi

  for uid in $UIDS; do
    # 同一个 UID 只应用一次（多用户解析、重复包名都可能重复返回）
    case " $NEW " in
      *" $uid "*) continue ;;
    esac

    # 先清掉这个 UID 的旧引用，避免重复规则导致计数不一致
    while iptables -D OUTPUT -m owner --uid-owner "$uid" -j "$CHAIN4" 2>/dev/null; do :; done
    iptables -I OUTPUT 1 -m owner --uid-owner "$uid" -j "$CHAIN4"
    if command -v ip6tables >/dev/null 2>&1; then
      while ip6tables -D OUTPUT -m owner --uid-owner "$uid" -j "$CHAIN6" 2>/dev/null; do :; done
      ip6tables -I OUTPUT 1 -m owner --uid-owner "$uid" -j "$CHAIN6"
    fi
    NEW="$NEW $uid"
    log "applied: pkg=$pkg uid=$uid iface=$TUN_IF"
  done
done < "$CONF"

echo $NEW > "$STATE"
log "done: uids=$NEW"
log "chain4=$(iptables -S "$CHAIN4" 2>&1 | tr '\n' '|')"
log "refs4=$(iptables -S OUTPUT 2>&1 | grep "$CHAIN4" | tr '\n' '|')"
