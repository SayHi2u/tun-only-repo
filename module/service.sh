#!/system/bin/sh
# KernelSU 开机服务脚本：等待系统启动完成后应用规则。
# 规则不依赖 v2rayNG 是否已启动：tun0 不存在时 app 会被阻断，tun0 出现后自动放行。

MODDIR=${0%/*}
LOG="$MODDIR/apply.log"

while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done

# 等 package manager 和网络服务就绪
sleep 8

sh "$MODDIR/apply.sh"

# 可选：用 inotifyd 监听包安装/卸载（基于事件，不轮询、不耗电）。
# 重装 app 或安装“手动输入但尚未安装”的包名后，会自动重跑 apply.sh。
# 如果 ROM 没有 /data/system/packages.xml 或 inotifyd 不可用，则不启动任何后台轮询；
# 重装/新装后到 WebUI 点“重新应用规则”，或重启手机。
if command -v inotifyd >/dev/null 2>&1 && [ -f /data/system/packages.xml ]; then
  nohup inotifyd "$MODDIR/on_change.sh" /data/system/packages.xml:w >/dev/null 2>&1 &
  echo "$(date '+%Y-%m-%d %H:%M:%S') inotifyd started" >> "$LOG"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') inotifyd unavailable; no polling fallback; reapply manually after package changes" >> "$LOG"
fi
