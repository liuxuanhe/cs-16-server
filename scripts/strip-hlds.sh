#!/bin/bash
# 精简 HLDS 专用服体积：删除客户端/半条命单机内容，保留开服必需文件
set -euo pipefail

HLDS="${1:-/opt/steam/hlds}"
CSTRIKE="${HLDS}/cstrike"

echo "[strip] HLDS=${HLDS}"

# 半条命单机资源可删；sprites/models/wad/dlls 需保留
rm -rf \
  "${HLDS}/valve/maps" \
  "${HLDS}/valve/sound" \
  "${HLDS}/valve/media" \
  "${HLDS}/valve/gfx" \
  "${HLDS}/valve/overviews" \
  "${HLDS}/valve/cl_dlls" \
  "${HLDS}/valve/resource" \
  "${HLDS}/valve/logos" \
  "${HLDS}/valve/controller_configs" \
  "${HLDS}/valve/cached" \
  2>/dev/null || true

# 客户端专用 / 调试
rm -rf \
  "${CSTRIKE}/cl_dlls" \
  "${CSTRIKE}/gfx" \
  "${HLDS}/linux64" \
  "${HLDS}/hltv" \
  "${HLDS}/demoplayer.so" \
  "${HLDS}/vgui.so" \
  "${HLDS}/vgui2.so" \
  2>/dev/null || true

find "${HLDS}" -type f \( \
  -iname '*.exe' -o -iname '*.dll' -o -iname '*.pdb' -o \
  -iname '*.bat' -o -iname '*.cmd' \
\) -delete 2>/dev/null || true

rm -rf "${CSTRIKE}/addons/amxmodx/scripting" 2>/dev/null || true

find "${HLDS}" -type f \( \
  -iname '*.md' -o -iname 'README*' -o -iname 'CHANGELOG*' \
\) ! -path '*/addons/amxmodx/configs/*' -delete 2>/dev/null || true

if [ ! -f "${HLDS}/valve/gfx.wad" ] && [ ! -f "${CSTRIKE}/gfx.wad" ]; then
  echo "[strip] 错误: 缺少 gfx.wad，拒绝继续" >&2
  ls -la "${HLDS}/valve"/*.wad 2>/dev/null || true
  exit 1
fi

find "${HLDS}" -type d -empty -delete 2>/dev/null || true

echo "[strip] 完成，当前体积："
du -sh "${HLDS}" "${HLDS}/valve" "${CSTRIKE}" 2>/dev/null || true
ls -la "${HLDS}/valve"/*.wad 2>/dev/null || true
