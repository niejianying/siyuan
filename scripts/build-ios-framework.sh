#!/bin/bash
# 构建 iOS XCFramework (gomobile bind)
# 用法: build-ios-framework.sh <kernel_dir> [output_dir]
# 默认输出: kernel_dir/SiYuanKernel.xcframework
set -e

if [ -z "$1" ]; then
  echo "用法: build-ios-framework.sh <kernel_dir> [output_dir]"
  exit 1
fi

KERNEL_DIR="$(cd "$1" && pwd)"
OUTPUT_DIR="${2:-$KERNEL_DIR}"
case "$OUTPUT_DIR" in
  /*) ;;
  *) OUTPUT_DIR="$(pwd)/$OUTPUT_DIR" ;;
esac

export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
command -v gomobile >/dev/null 2>&1 || { echo "❌ gomobile 未安装，请先执行: go install golang.org/x/mobile/cmd/gomobile@latest"; exit 1; }

cd "$KERNEL_DIR"
gomobile init 2>/dev/null || true
gomobile bind -tags fts5 -ldflags '-s -w' -v \
  -o "$OUTPUT_DIR/SiYuanKernel.xcframework" \
  -target=ios ./mobile/

echo "XCFramework 已输出: $OUTPUT_DIR/SiYuanKernel.xcframework"
