#!/bin/sh
# build.sh - 编译 + 签名 + 打包 MG27.ipa
#
# 签名信息全部从环境变量读，不写死在仓库里：
#
#   IDENT="iPhone Distribution: Your Name (TEAMID)" \
#   APP_ID="TEAMID.com.example.mg27" \
#   TEAM_ID="TEAMID" \
#   APP_GROUPS="group.abc.1 group.abc.2" \
#   PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/xxx.mobileprovision" \
#   ./build.sh
#
# 也可以放在同目录的 .env.local（已在 .gitignore 里）：
#   . ./.env.local && ./build.sh
set -eu
cd "$(dirname "$0")"

# 同目录的 .env.local 会被自动加载（已在 .gitignore 里）
if [ -f .env.local ]; then
  set -a
  . ./.env.local
  set +a
fi

# ---- 签名配置 ------------------------------------------------------------
IDENT="${IDENT:-}"
APP_ID="${APP_ID:-}"
TEAM_ID="${TEAM_ID:-}"
APP_GROUPS="${APP_GROUPS:-}"
PROFILE="${PROFILE:-$HOME/Library/MobileDevice/Provisioning Profiles/描述文件.mobileprovision}"

if [ -z "$IDENT" ] || [ -z "$APP_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_GROUPS" ]; then
  cat >&2 <<'EOF'
缺少签名配置。需要这几个环境变量：

  IDENT       codesign 身份，如 "iPhone Distribution: Name (TEAMID)"
  APP_ID      application-identifier，如 "TEAMID.com.example.mg27"
  TEAM_ID     team identifier，如 "TEAMID"
  APP_GROUPS  App Group，空格分隔多个，如 "group.abc.1 group.abc.2"
  PROFILE     描述文件路径（可选，有默认值）

示例：

  IDENT="iPhone Distribution: Name (TEAMID)" \
  APP_ID="TEAMID.com.example.mg27" \
  TEAM_ID="TEAMID" \
  APP_GROUPS="group.abc.1 group.abc.2" \
  ./build.sh
EOF
  exit 1
fi

BUNDLE_ID="${APP_ID#*.}"          # 去掉 TEAMID. 前缀
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
APP=build/Payload/MG27.app
OUT="$(pwd)/MG27.ipa"

rm -rf build
mkdir -p "$APP" build/obj

# ---- 生成 entitlements ---------------------------------------------------
{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>application-identifier</key>
	<string>${APP_ID}</string>
	<key>com.apple.developer.team-identifier</key>
	<string>${TEAM_ID}</string>
	<key>get-task-allow</key>
	<false/>
	<key>com.apple.security.application-groups</key>
	<array>
EOF
  for g in $APP_GROUPS; do
    printf '\t\t<string>%s</string>\n' "$g"
  done
  cat <<'EOF'
	</array>
</dict>
</plist>
EOF
} > build/entitlements.plist

# ---- 生成 Info.plist（bundle id 跟签名配置一致）---------------------------
sed "s|<string>app.azure8693.silver9606</string>|<string>${BUNDLE_ID}</string>|" \
  Info.plist > build/Info.plist

# ---- 编译 ----------------------------------------------------------------
clang -target arm64-apple-ios18.0 -isysroot "$SDK" -O2 -w \
  -c worse_query.m -o build/obj/worse_query.o
clang -target arm64-apple-ios18.0 -isysroot "$SDK" -O2 -w \
  -c GestaltAccess.m -o build/obj/GestaltAccess.o

swiftc -O -parse-as-library -sdk "$SDK" -target arm64-apple-ios18.0 \
  -import-objc-header Bridge.h \
  -framework UIKit -framework SwiftUI -framework Foundation -framework WebKit \
  -o "$APP/MG27" \
  GestaltLabApp.swift GestaltViewModel.swift GestaltModels.swift \
  GestaltTweaks.swift GestaltBackupStore.swift ContentView.swift \
  MGTheme.swift NeoSpringView.swift AutomationCommand.swift \
  build/obj/worse_query.o build/obj/GestaltAccess.o

cp build/Info.plist "$APP/Info.plist"

if [ ! -f "$PROFILE" ]; then
  echo "描述文件不存在: $PROFILE" >&2
  exit 1
fi
cp "$PROFILE" "$APP/embedded.mobileprovision"

# ---- 签名 + 打包 ---------------------------------------------------------
codesign -f -s "$IDENT" --entitlements build/entitlements.plist --timestamp=none "$APP"
( cd build && zip -qry ../MG27.ipa Payload )
mv -f MG27.ipa "$OUT"

echo "──────── 装这个 ────────"
echo "文件  $OUT"
echo "大小  $(stat -f%z "$OUT") 字节"
echo "SHA   $(shasum -a 256 "$OUT" | cut -c1-16)"
echo
codesign -d --entitlements - "$APP" 2>/dev/null | grep -A8 application-groups
