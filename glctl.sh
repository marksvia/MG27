#!/bin/sh
# glctl.sh - 从 Mac 驱动 MG27，手机上不用点。
#
#   ./glctl.sh dump                     导出当前 plist 到 App 的 Documents
#   ./glctl.sh siri                     Siri AI 强开（只改 RegionCode 为 LL）
#   ./glctl.sh region CH                写区域码（CH / LL / 任意两字母）
#   ./glctl.sh key "KEY=1"              写任意 CacheExtra 键
#   ./glctl.sh pull                     把导出的 plist 拉到本地
#
# 前提：手机已装 MG27.ipa，USB 连接并已信任本机。
set -eu
cd "$(dirname "$0")"

BUNDLE="app.azure8693.silver9606"
IPA="$(pwd)/MG27.ipa"
UDID="${GESTALTLAB_UDID:-}"
MODE="${1:-dump}"
shift || true

if [ -z "$UDID" ]; then
  UDID=$(idevice_id -l 2>/dev/null | head -1 || true)
fi
if [ -z "$UDID" ]; then
  echo "找不到设备：插 USB 并在手机上点「信任」" >&2
  exit 1
fi
echo "device  $UDID"

if ! ideviceinstaller -u "$UDID" list 2>/dev/null | grep -q "$BUNDLE"; then
  echo "未安装，正在安装 $IPA"
  ideviceinstaller -u "$UDID" install "$IPA"
fi

case "$MODE" in
  dump)
    ARGS="--dump"
    ;;
  region)
    CODE="${1:-CH}"
    ARGS="--set-region $CODE"
    ;;
  siri)
    ARGS="--siri-ai"
    ;;
  key)
    [ $# -ge 1 ] || { echo "用法: $0 key KEY=VALUE" >&2; exit 2; }
    ARGS="--set-key $1"
    ;;
  pull)
    afcclient -u "$UDID" --documents "$BUNDLE" <<'EOF'
get MobileGestalt-dump.plist
EOF
    echo "已拉到当前目录"
    exit 0
    ;;
  *)
    echo "用法: $0 {dump|region CODE|key KEY=VALUE|pull}" >&2
    exit 2
    ;;
esac

LOG=$(mktemp -t gestaltlab)
set +e
xcrun devicectl device process launch \
  --device "$UDID" \
  --console \
  --terminate-existing \
  "$BUNDLE" $ARGS 2>&1 | tee "$LOG" | grep --line-buffered "GESTALTLAB"
set -e

echo
if grep -q "GESTALTLAB_SUCCESS" "$LOG"; then
  echo "结果  ok"
  rm -f "$LOG"
  exit 0
fi
echo "结果  fail   （完整日志 $LOG）"
exit 1
