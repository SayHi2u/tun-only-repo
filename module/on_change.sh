#!/system/bin/sh
# 包数据库变化后重新解析 UID（安装/卸载/更新都会触发）。
# 由 inotifyd 调用，参数是事件和文件名，这里不需要使用。

MODDIR=${0%/*}

# 等 package manager 完成本次安装/卸载
sleep 3

sh "$MODDIR/apply.sh"
