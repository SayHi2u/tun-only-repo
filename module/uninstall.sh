#!/system/bin/sh
# KernelSU 卸载模块时清理规则。
# 如果 uids.state 丢失，可能无法删除所有 OUTPUT 引用；卸载后重启可清空 iptables。

MODDIR=${0%/*}
STATE="$MODDIR/uids.state"
CHAIN4="TUN_ONLY_APPS"
CHAIN6="TUN_ONLY_APPS6"

if [ -f "$STATE" ]; then
  for old in $(cat "$STATE"); do
    while iptables -D OUTPUT -m owner --uid-owner "$old" -j "$CHAIN4" 2>/dev/null; do :; done
    while ip6tables -D OUTPUT -m owner --uid-owner "$old" -j "$CHAIN6" 2>/dev/null; do :; done
  done
fi

iptables -F "$CHAIN4" 2>/dev/null
iptables -X "$CHAIN4" 2>/dev/null
ip6tables -F "$CHAIN6" 2>/dev/null
ip6tables -X "$CHAIN6" 2>/dev/null
