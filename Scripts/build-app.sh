#!/bin/bash
# PlainPaste.app バンドルをビルドする。
# 使い方: ./Scripts/build-app.sh
# 出力: build/PlainPaste.app
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="build/PlainPaste.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/PlainPaste "$APP/Contents/MacOS/PlainPaste"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# アドホック署名(これがないとアクセシビリティ権限が再ビルドのたびにリセットされる)
codesign --force --sign - "$APP"

echo "✅ ビルド完了: $APP"
echo "   open $APP で起動できます"
