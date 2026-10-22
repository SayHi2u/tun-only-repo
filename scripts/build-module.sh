#!/usr/bin/env bash
# 打包 KernelSU 模块。zip 根目录必须包含 module.prop。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist"
mkdir -p "$OUT"

cd "$ROOT/module"
rm -f "$OUT/tun-only-ksu.zip"
zip -r "$OUT/tun-only-ksu.zip" . \
  -x 'uids.state' \
  -x 'apply.log' \
  -x '*.log' \
  -x '.DS_Store'

echo "built: $OUT/tun-only-ksu.zip"
unzip -l "$OUT/tun-only-ksu.zip" | sed -n '1,20p'
