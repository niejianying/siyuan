#!/bin/bash
# 构建 Android AAR (gomobile bind)
# 用法: build-android-aar.sh <kernel_dir> [output_file]
# 默认输出: kernel_dir/siyuan-kernel.aar
set -e

KERNEL_DIR="$1"
OUTPUT_FILE="${2:-$KERNEL_DIR/siyuan-kernel.aar}"

if [ -z "$KERNEL_DIR" ]; then
  echo "用法: build-android-aar.sh <kernel_dir> [output_file]"
  exit 1
fi

export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
command -v gomobile >/dev/null 2>&1 || { echo "❌ gomobile 未安装，请先执行: go install golang.org/x/mobile/cmd/gomobile@latest"; exit 1; }

cd "$KERNEL_DIR"
gomobile init 2>/dev/null || true
gomobile bind -tags fts5 -ldflags '-s -w' -v \
  -o "$OUTPUT_FILE" \
  -target android/arm64 -androidapi 26 ./mobile/

echo "AAR 已输出: $OUTPUT_FILE ($(ls -lh "$OUTPUT_FILE" | awk '{print $5}'))"
