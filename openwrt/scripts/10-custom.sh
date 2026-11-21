#!/bin/bash
# 自定义构建脚本 —— 为 HY3000 打开 FUSE，让 CloudDrive2 能挂载
#
# 背景：padavanonly/immortalwrt-mt798x-6.6 的 MTK 闭源内核默认没编 FUSE
#       （实测符号 /dev/fuse、fuse_conn、fuse_file 全为 0），CloudDrive2 必然挂不上。
# 做法：1) 直接改内核对配置文件，写入 CONFIG_FUSE_FS=m
#       2) 往 24-config-general 追加 kmod-fuse / libfuse 系列包选择
# 两个动作都做了幂等处理，重复跑构建不会叠加。

set +e

log() { echo ">>> [fuse] $*"; }

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." 2>/dev/null && pwd)"

log "脚本目录=$SELF_DIR"
log "仓库根=$REPO_ROOT"
log "当前目录=$(pwd)"

# ---------- 1) 找到源码根（含 target/linux 的那一层） ----------
SRC_ROOT=""
for c in "$REPO_ROOT/openwrt" "$(pwd)" "$REPO_ROOT" "$SELF_DIR/.."; do
    if [ -n "$c" ] && [ -d "$c/target/linux" ]; then
        SRC_ROOT="$c"; break
    fi
done
if [ -z "$SRC_ROOT" ]; then
    d="$(find "$REPO_ROOT" -maxdepth 5 -type d -name target 2>/dev/null | head -1)"
    [ -n "$d" ] && [ -d "$d/linux" ] && SRC_ROOT="$(dirname "$d")"
fi

if [ -z "$SRC_ROOT" ]; then
    log "!!! 找不到源码根(target/linux)，内核 FUSE 改动跳过"
else
    log "源码根=$SRC_ROOT"

    n=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        sed -i '/^CONFIG_FUSE_FS/d' "$f" 2>/dev/null
        sed -i '/^# CONFIG_FUSE_FS is not set/d' "$f" 2>/dev/null
        echo 'CONFIG_FUSE_FS=m' >> "$f"
        log "内核配置写入 $f"
        n=$((n+1))
    done <<EOF
$(find "$SRC_ROOT/target/linux" -maxdepth 3 -type f -name 'config-6.*' 2>/dev/null)
EOF
    log "共改写 $n 个内核配置文件"

    # 兜底：generic 目录单独再确认一次
    for f in $(find "$SRC_ROOT/target/linux/generic" -maxdepth 1 -type f -name 'config-6.*' 2>/dev/null); do
        grep -q '^CONFIG_FUSE_FS' "$f" || echo 'CONFIG_FUSE_FS=m' >> "$f"
    done

    log "当前内核配置状态："
    grep -rn 'CONFIG_FUSE_FS' "$SRC_ROOT/target/linux" --include='config-6.*' 2>/dev/null | sed 's/^/    /'
fi

# ---------- 2) 追加包选择到 24-config-general（可能不止一份，全部追加） ----------
MARK='##### HY3000-FUSE-PACKAGES (auto-generated) #####'

cfgs="$(find "$REPO_ROOT" -maxdepth 3 -type f -name '24-config-general' 2>/dev/null)"
if [ -z "$cfgs" ]; then
    log "!!! 没找到 24-config-general，包选择跳过"
else
    for f in $cfgs; do
        if grep -q "$MARK" "$f" 2>/dev/null; then
            log "已存在自定义段，跳过 $f"
            continue
        fi
        {
            echo ''
            echo "$MARK"
            echo 'CONFIG_PACKAGE_kmod-fuse=y'
            echo 'CONFIG_PACKAGE_libfuse1=y'
            echo 'CONFIG_PACKAGE_libfuse=y'
            echo 'CONFIG_PACKAGE_libfuse3-3=y'
            echo 'CONFIG_PACKAGE_libfuse3=y'
            echo 'CONFIG_PACKAGE_fuse-utils=y'
            echo 'CONFIG_PACKAGE_fuse3-utils=y'
            echo 'CONFIG_PACKAGE_fuse-overlayfs=y'
            echo 'CONFIG_PACKAGE_kmod-veth=y'
            echo 'CONFIG_PACKAGE_kmod-br-netfilter=y'
            echo 'CONFIG_PACKAGE_kmod-nf-nat=y'
        } >> "$f"
        log "包选择追加到 $f"
    done
fi

log "自定义脚本执行完毕"
