#!/system/bin/sh
# KernelSU/Magisk 安装脚本：升级模块时保留已有的 packages.conf，
# 避免 zip 里的默认包名覆盖用户通过 WebUI 保存的配置。

OLD="/data/adb/modules/tun-only-ksu/packages.conf"
if [ -n "$MODPATH" ] && [ -f "$OLD" ] && [ -f "$MODPATH/packages.conf" ]; then
  cp -f "$OLD" "$MODPATH/packages.conf"
fi
