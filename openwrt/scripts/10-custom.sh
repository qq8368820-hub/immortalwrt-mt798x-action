#!/bin/bash
# 自定义构建脚本 —— 给 MTK 6.6 闭源内核打开 FUSE（CloudDrive2 挂载所需）
#
# 本脚本由 build.sh 在源码根目录(/builder/openwrt)以 `bash 10-custom.sh` 执行。
# 这里只做一件事：把 CONFIG_FUSE_FS=m 写进内核 config 文件。
# 用户态库与 kmod-fuse 的包选择已静态写在 openwrt/24-config-general 里。

set +e

log() { echo ">>> [fuse] $*"; }

# 1) 定位源码根（含 target/linux 的那一层）
SRC_ROOT=""
for c in "$(pwd)" "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"; do
    if [ -n "$c" ] && [ -d "$c/target/linux" ]; then
        SRC_ROOT="$c"; break
    fi
done

if [ -z "$SRC_ROOT" ]; then
    log "!!! 找不到 target/linux，跳过内核改动"
    exit 0
fi
log "源码根 = $SRC_ROOT"

# 2) 逐个改写内核对配置文件
n=0
for f in $(find "$SRC_ROOT/target/linux" -maxdepth 3 -type f -name 'config-6.*' 2>/dev/null); do
    sed -i '/^CONFIG_FUSE_FS/d' "$f" 2>/dev/null
    sed -i '/^# CONFIG_FUSE_FS is not set/d' "$f" 2>/dev/null
    echo 'CONFIG_FUSE_FS=m' >> "$f"
    log "写入 $f"
    n=$((n+1))
done
log "共改写 $n 个内核配置文件"

# 3) 打印结果，方便在 Actions 日志里核对
grep -rn 'CONFIG_FUSE_FS' "$SRC_ROOT/target/linux" --include='config-6.*' 2>/dev/null | sed 's/^/    /'

log "完成"
