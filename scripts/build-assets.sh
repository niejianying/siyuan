#!/bin/bash
# 构建 Web 前端 + 打包 assets.tar.gz
# 用法: build-assets.sh <siyuan_dir> <output_dir>
# 输出: $output_dir/siyuan-assets.tar.gz
set -e

SIYUAN_DIR="$1"
OUTPUT_DIR="$2"

if [ -z "$SIYUAN_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "用法: build-assets.sh <siyuan_dir> <output_dir>"
  exit 1
fi

echo "=== 构建 Web 前端 (mobile) ==="
cd "$SIYUAN_DIR/app"
if ! WEBPACK=$(node -e "console.log(require.resolve('webpack/bin/webpack.js'))" 2>/dev/null); then
  echo "  ⚠️  webpack 未安装，运行 npm install..."
  npm install --no-package-lock 2>&1 || { echo "npm install 失败"; exit 1; }
  WEBPACK=$(node -e "console.log(require.resolve('webpack/bin/webpack.js'))")
fi
node "$WEBPACK" --mode production --config webpack.mobile.js 2>&1 | tail -1

echo "=== 注入 shim + 主题 CSS ==="
for dir in "$SIYUAN_DIR/app/stage/build/mobile"; do
  cat > "$dir/shim.js" << 'JSEOF'
window.JSHarmony=void 0
if(!window.ResizeObserver){window.ResizeObserver=function(){this.observe=function(){};this.unobserve=function(){};this.disconnect=function(){}}}
window.onerror=function(){return true}
if(typeof window.addEventListener==='function'){var _ae=window.addEventListener;window.addEventListener=function(t,f,o){if(t==='keydown'||t==='beforeunload'||t==='pagehide'){try{_ae(t,function(e){try{f(e)}catch(ex){}},o)}catch(ex){}}else{_ae(t,f,o)}}}
JSEOF
  sed -i '' 's|<script defer|<script src="shim.js"></script><script defer|' "$dir/index.html" 2>/dev/null
  sed -i '' 's|</head>|<link href="/appearance/themes/midnight/theme.css" rel="stylesheet"></head>|' "$dir/index.html" 2>/dev/null
done

echo "=== 打包到 Flutter assets ==="
rm -rf "$OUTPUT_DIR" && mkdir -p "$OUTPUT_DIR"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
APP_DIR="$TMPDIR/app"
mkdir -p "$APP_DIR"

rsync -a --delete --exclude='build/app' \
  "$SIYUAN_DIR/app/stage/" "$APP_DIR/stage/"
rsync -a --delete --exclude='LICENSE' \
  "$SIYUAN_DIR/app/appearance/" "$APP_DIR/appearance/"
echo "// empty" > "$APP_DIR/stage/service-worker.js"

# 前端新版本请求 en.json（不再使用 en_US.json），拷贝一份
[ -f "$APP_DIR/appearance/langs/en_US.json" ] && \
  cp "$APP_DIR/appearance/langs/en_US.json" "$APP_DIR/appearance/langs/en.json"

# 前端新版本默认使用 litheness 图标集（从 material 复制一份）
mkdir -p "$APP_DIR/appearance/icons/litheness"
if [ -f "$APP_DIR/appearance/icons/material/icon.js" ]; then
  cp "$APP_DIR/appearance/icons/material/icon.js" "$APP_DIR/appearance/icons/litheness/icon.js"
  cp "$APP_DIR/appearance/icons/material/icon.json" "$APP_DIR/appearance/icons/litheness/icon.json"
fi

# 排除 Apple Double + 使用 ustar 格式（Dart TarDecoder 不支持 PAX 头）
COPYFILE_DISABLE=1 tar cf - --exclude='._*' --format=ustar -C "$TMPDIR" . | gzip -n > "$OUTPUT_DIR/siyuan-assets.tar.gz"

echo "assets 已输出: $OUTPUT_DIR/siyuan-assets.tar.gz ($(ls -lh "$OUTPUT_DIR/siyuan-assets.tar.gz" | awk '{print $5}'))"
