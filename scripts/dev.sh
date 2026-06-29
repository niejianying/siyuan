#!/bin/bash
# 全量构建：编译内核 → 构建前端 → 打包到 Flutter
# Flutter 项目只需 flutter run -d <device>
set -e

SIYUAN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$SIYUAN_DIR/scripts"
NIJIANYING_DIR="$(cd "$SIYUAN_DIR/../niejianying" && pwd 2>/dev/null)" || {
  echo "❌ 未找到 ../niejianying（Flutter 项目）"
  exit 1
}
OUTPUT_DIR="$NIJIANYING_DIR/asset/siyuan"

# 停止已有内核
EXISTING_PID=$(pgrep -f "SiYuan-Kernel" | head -1)
if [ -n "$EXISTING_PID" ]; then
  echo "=== 停止已有内核 (PID $EXISTING_PID) ==="
  kill "$EXISTING_PID" 2>/dev/null
  for i in $(seq 1 10); do
    kill -0 "$EXISTING_PID" 2>/dev/null || break
    sleep 1
  done
  kill -0 "$EXISTING_PID" 2>/dev/null && kill -9 "$EXISTING_PID" 2>/dev/null || true
fi

echo "=== [1/4] 编译 Go 内核 (desktop) ==="
cd "$SIYUAN_DIR/kernel"
CGO_ENABLED=1 go build -tags "fts5" -o "$SIYUAN_DIR/app/kernel/SiYuan-Kernel"

echo "=== [2/4] 构建 Web 前端 (desktop) ==="
cd "$SIYUAN_DIR/app"
if ! WEBPACK=$(node -e "console.log(require.resolve('webpack/bin/webpack.js'))" 2>/dev/null); then
  echo "  ⚠️  webpack 未安装，运行 npm install..."
  npm install --no-package-lock 2>&1 || { echo "npm install 失败"; exit 1; }
  WEBPACK=$(node -e "console.log(require.resolve('webpack/bin/webpack.js'))")
fi
node "$WEBPACK" --mode production --config webpack.desktop.js 2>&1 | tail -1

echo "=== [3/4] 构建移动端 assets ==="
"$SCRIPTS_DIR/build-assets.sh" "$SIYUAN_DIR" "$OUTPUT_DIR"

echo "=== [4/4] 构建 iOS Framework ==="
"$SCRIPTS_DIR/build-ios-framework.sh" "$SIYUAN_DIR/kernel"
cp -Rf "$SIYUAN_DIR/kernel/SiYuanKernel.xcframework" "$NIJIANYING_DIR/ios/Frameworks/SiYuanKernel.xcframework"
echo "iOS Framework 已部署到 Flutter 项目"

echo ""
echo "=== 完成 ==="
echo "输出: $OUTPUT_DIR/siyuan-assets.tar.gz ($(ls -lh "$OUTPUT_DIR/siyuan-assets.tar.gz" | awk '{print $5}'))"

# 清理 workspace.json 中的旧路径
WS_JSON="$HOME/.config/siyuan/workspace.json"
[ -f "$WS_JSON" ] && python3 -c "
import json
with open('$WS_JSON') as f: ws = json.load(f)
ws = [w for w in ws if w != '/tmp/siyuan-dev']
with open('$WS_JSON', 'w') as f: json.dump(ws, f)
" 2>/dev/null || true
