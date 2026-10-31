#!/bin/bash
# On Time 7 Mac 版云端构建脚本（GitHub Actions 调用）
# 由 .github/workflows/build-dmg.yml 调用：bash build-mac.sh
# 以后构建逻辑只改这一个文件即可，workflow 不用再动。
set -e

APP="OnTime.app"
rm -rf "$APP" Ontime-7-mac-arm64.dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 确保用 Xcode 的命令行工具
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer 2>/dev/null || true

# 直接编译 5 个 swift 文件，无需 Xcode 工程
# 注意：云机器本身就是 arm64，不要加 -target 参数
swiftc -O -o "$APP/Contents/MacOS/OnTime" \
  OnTimeApp.swift ContentView.swift CountdownView.swift ClockView.swift Models.swift RemoteServer.swift \
  -framework SwiftUI -framework AppKit -framework Carbon

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>OnTime</string>
  <key>CFBundleDisplayName</key>
  <string>On Time 7</string>
  <key>CFBundleIdentifier</key>
  <string>com.taoskx.ontime</string>
  <key>CFBundleVersion</key>
  <string>7.0</string>
  <key>CFBundleShortVersionString</key>
  <string>7.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>OnTime</string>
  <key>CFBundleIconFile</key>
  <string>OnTime</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF
echo "APPL????" > "$APP/Contents/PkgInfo"

# 图标：Swift 脚本在云机器上直接绘制 iconset -> OnTime.icns
# （不推送 PNG：推送工具对二进制只会原样存文本，sips/iconutil 读不了）
swift make-icon.swift
iconutil -c icns OnTime.iconset -o "$APP/Contents/Resources/OnTime.icns"
rm -rf OnTime.iconset
ls -lh "$APP/Contents/Resources/OnTime.icns"
# ad-hoc 签名：没有签名会被 Gatekeeper 直接判"已损坏"；
# ad-hoc 签名后首次打开走"右键 → 打开"即可
codesign --force --deep --sign - "$APP"
ls -lh "$APP/Contents/MacOS/OnTime"

# 打包 dmg：带"应用程序"快捷方式，拖进去即安装
DMGROOT="dmgroot"
rm -rf "$DMGROOT"; mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/"
ln -s /Applications "$DMGROOT/Applications"
hdiutil create -volname "On Time 7" \
  -srcfolder "$DMGROOT" -ov -format UDZO \
  Ontime-7-mac-arm64.dmg
rm -rf "$DMGROOT"
ls -lh Ontime-7-mac-arm64.dmg
echo "构建完成"
