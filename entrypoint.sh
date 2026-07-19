#!/bin/bash
# ============================================================
# CS 1.6 服务器启动脚本
# 根据环境变量生成运行时配置，并启动 ReHLDS
# ============================================================
set -euo pipefail

HLDS_DIR="/opt/steam/hlds"
CSTRIKE_DIR="${HLDS_DIR}/cstrike"
METAMOD_PLUGINS="${CSTRIKE_DIR}/addons/metamod/plugins.ini"
CUSTOM_MAPS_DIR="/opt/steam/custom_maps"
CONFIG_SRC_DIR="/opt/steam/config_src"
RUNTIME_CFG="${CSTRIKE_DIR}/server.cfg"
BOTS_CFG="${CSTRIKE_DIR}/bots.cfg"
AMXX_CFG_DIR="${CSTRIKE_DIR}/addons/amxmodx/configs"
USERS_INI="${AMXX_CFG_DIR}/users.ini"
AMXX_CFG="${AMXX_CFG_DIR}/amxx.cfg"
AMXX_CN_CFG="${AMXX_CFG_DIR}/amxx_chinese.cfg"

# ---------- 默认环境变量 ----------
SERVER_NAME="${SERVER_NAME:-CS 1.6 Server}"
RCON_PASSWORD="${RCON_PASSWORD:-changeme}"
SERVER_PASSWORD="${SERVER_PASSWORD:-}"
START_MAP="${START_MAP:-de_dust2}"
MAXPLAYERS="${MAXPLAYERS:-16}"
TICKRATE="${TICKRATE:-100}"
START_MONEY="${START_MONEY:-800}"
PORT="${PORT:-27015}"
ENABLE_BOTS="${ENABLE_BOTS:-0}"
BOT_QUOTA="${BOT_QUOTA:-4}"
BOT_JOIN_TEAM="${BOT_JOIN_TEAM:-any}"
BOT_NAME_PREFIX="${BOT_NAME_PREFIX:-}"
# 难度：0=简单 1=普通 2=中等 3=困难 4=变态；也可用 easy/average/normal/hard/godlike
BOT_DIFFICULTY="${BOT_DIFFICULTY:-0}"
ADMIN_NAME="${ADMIN_NAME:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ADMIN_STEAMID="${ADMIN_STEAMID:-}"
ADMIN_FLAGS="${ADMIN_FLAGS:-abcdefghijklmnopqrstu}"

# 自动探测 YaPB 插件路径（不同版本文件名可能不同）
YAPB_SO=""
if [ -f "${CSTRIKE_DIR}/addons/yapb/bin/yapb_mm_i386.so" ]; then
  YAPB_SO="addons/yapb/bin/yapb_mm_i386.so"
elif [ -f "${CSTRIKE_DIR}/addons/yapb/bin/yapb.so" ]; then
  YAPB_SO="addons/yapb/bin/yapb.so"
else
  YAPB_SO="$(find "${CSTRIKE_DIR}/addons/yapb" -name '*.so' 2>/dev/null | head -n 1 | sed "s|^${CSTRIKE_DIR}/||")"
fi
YAPB_LINE="linux ${YAPB_SO}"

echo "[entrypoint] 服务器名: ${SERVER_NAME}"
echo "[entrypoint] 启动地图: ${START_MAP}"
echo "[entrypoint] 最大人数: ${MAXPLAYERS}"
echo "[entrypoint] 初始金钱: ${START_MONEY}"
echo "[entrypoint] 机器人: ENABLE_BOTS=${ENABLE_BOTS}"

# ---------- 同步自定义地图 / 资源 ----------
# .bsp/.nav/.res/.txt → cstrike/maps/
# .wad → cstrike/（引擎从游戏根目录加载材质包，放 maps/ 下常找不到）
if [ -d "${CUSTOM_MAPS_DIR}" ]; then
  echo "[entrypoint] 同步自定义地图: ${CUSTOM_MAPS_DIR} -> ${CSTRIKE_DIR}/maps"
  mkdir -p "${CSTRIKE_DIR}/maps"
  find "${CUSTOM_MAPS_DIR}" -maxdepth 1 -type f \( \
      -iname '*.bsp' -o -iname '*.nav' -o -iname '*.res' -o -iname '*.txt' -o -iname '*.detail' \
    \) ! -name 'README.txt' -exec cp -f {} "${CSTRIKE_DIR}/maps/" \;
  find "${CUSTOM_MAPS_DIR}" -maxdepth 1 -type f -iname '*.wad' -print0 \
    | while IFS= read -r -d '' wad; do
        echo "[entrypoint] 同步 WAD: $(basename "${wad}") -> ${CSTRIKE_DIR}/"
        cp -f "${wad}" "${CSTRIKE_DIR}/"
      done
fi

# ---------- 同步可覆盖的配置 ----------
sync_config_file() {
  local name="$1"
  local dest="$2"
  if [ -f "${CONFIG_SRC_DIR}/${name}" ]; then
    echo "[entrypoint] 使用挂载配置: ${name}"
    cp -f "${CONFIG_SRC_DIR}/${name}" "${dest}"
  elif [ -f "/opt/steam/defaults/${name}" ]; then
    cp -f "/opt/steam/defaults/${name}" "${dest}"
  fi
}

mkdir -p "${AMXX_CFG_DIR}"
sync_config_file "server_info.html" "${CSTRIKE_DIR}/server_info.html"
sync_config_file "amxx_chinese.cfg" "${AMXX_CN_CFG}"
sync_config_file "users.ini" "${USERS_INI}"
sync_config_file "reunion.cfg" "${CSTRIKE_DIR}/reunion.cfg"

# ---------- 写入运行时 server.cfg ----------
if [ -f "${CSTRIKE_DIR}/server.cfg.default" ]; then
  cp -f "${CSTRIKE_DIR}/server.cfg.default" "${RUNTIME_CFG}"
fi

set_cvar() {
  local key="$1"
  local value="$2"
  local file="$3"
  if grep -qE "^[[:space:]]*${key}[[:space:]]" "${file}" 2>/dev/null; then
    sed -i "s|^[[:space:]]*${key}[[:space:]].*|${key} \"${value}\"|" "${file}"
  else
    echo "${key} \"${value}\"" >> "${file}"
  fi
}

set_cvar "hostname" "${SERVER_NAME}" "${RUNTIME_CFG}"
set_cvar "rcon_password" "${RCON_PASSWORD}" "${RUNTIME_CFG}"
set_cvar "sv_password" "${SERVER_PASSWORD}" "${RUNTIME_CFG}"
set_cvar "sys_ticrate" "${TICKRATE}" "${RUNTIME_CFG}"
set_cvar "mp_startmoney" "${START_MONEY}" "${RUNTIME_CFG}"
set_cvar "motdfile" "server_info.html" "${RUNTIME_CFG}"

# ---------- AMXX 中文覆盖 ----------
if [ -f "${AMXX_CFG}" ] && [ -f "${AMXX_CN_CFG}" ]; then
  if grep -q 'AMXX_CHINESE_BEGIN' "${AMXX_CFG}" 2>/dev/null; then
    sed -i '/AMXX_CHINESE_BEGIN/,/AMXX_CHINESE_END/d' "${AMXX_CFG}"
  fi
  sed -i 's/^amx_language "en"/amx_language "cn"/' "${AMXX_CFG}" || true
  sed -i 's/^amx_client_languages 1/amx_client_languages 0/' "${AMXX_CFG}" || true
  {
    echo ""
    echo "// AMXX_CHINESE_BEGIN"
    cat "${AMXX_CN_CFG}"
    echo "// AMXX_CHINESE_END"
  } >> "${AMXX_CFG}"
  echo "[entrypoint] 已启用 AMXX 中文提示（amx_language cn）"
fi

# ---------- AMXX Admin ----------
write_amxx_admins() {
  local tmp
  tmp="$(mktemp)"
  if [ -f "${USERS_INI}" ]; then
    if grep -q 'AUTO_ADMIN_BEGIN' "${USERS_INI}" 2>/dev/null; then
      sed '/AUTO_ADMIN_BEGIN/,/AUTO_ADMIN_END/d' "${USERS_INI}" > "${tmp}"
    else
      cp -f "${USERS_INI}" "${tmp}"
    fi
  else
    : > "${tmp}"
  fi

  {
    echo ""
    echo "; AUTO_ADMIN_BEGIN"
    if [ -n "${ADMIN_STEAMID}" ]; then
      echo "\"${ADMIN_STEAMID}\" \"\" \"${ADMIN_FLAGS}\" \"ce\""
      echo "[entrypoint] AMXX Admin(SteamID): ${ADMIN_STEAMID}" >&2
    fi
    if [ -n "${ADMIN_NAME}" ] && [ -n "${ADMIN_PASSWORD}" ]; then
      echo "\"${ADMIN_NAME}\" \"${ADMIN_PASSWORD}\" \"${ADMIN_FLAGS}\" \"k\""
      echo "[entrypoint] AMXX Admin(名字+密码): ${ADMIN_NAME}" >&2
    fi
    if [ -z "${ADMIN_STEAMID}" ] && { [ -z "${ADMIN_NAME}" ] || [ -z "${ADMIN_PASSWORD}" ]; }; then
      echo "; （未配置 ADMIN_NAME/ADMIN_PASSWORD 或 ADMIN_STEAMID）"
      echo "[entrypoint] 警告: 未配置 AMXX 管理员环境变量" >&2
    fi
    echo "; AUTO_ADMIN_END"
  } >> "${tmp}"

  mv -f "${tmp}" "${USERS_INI}"
}

write_amxx_admins

# ---------- 机器人开关（YaPB） ----------
if [ -f "${METAMOD_PLUGINS}" ]; then
  sed -i '/yapb/Id' "${METAMOD_PLUGINS}" || true
fi

: > "${BOTS_CFG}"

# 将 BOT_DIFFICULTY 归一化为 YaPB 0-4
normalize_bot_difficulty() {
  local raw
  raw="$(echo "${1}" | tr '[:upper:]' '[:lower:]')"
  case "${raw}" in
    0|easy|simple|newbie|简单) echo "0" ;;
    1|average|普通) echo "1" ;;
    2|normal|中等) echo "2" ;;
    3|hard|pro|professional|困难) echo "3" ;;
    4|god|godlike|变态) echo "4" ;;
    *)
      echo "[entrypoint] 警告: 未知 BOT_DIFFICULTY=${1}，回退为 0（简单）" >&2
      echo "0"
      ;;
  esac
}

if [ "${ENABLE_BOTS}" = "1" ] || [ "${ENABLE_BOTS}" = "true" ] || [ "${ENABLE_BOTS}" = "yes" ]; then
  if [ -z "${YAPB_SO}" ]; then
    echo "[entrypoint] 警告: 未找到 YaPB 插件，无法启用机器人" >&2
  else
    BOT_DIFFICULTY_LEVEL="$(normalize_bot_difficulty "${BOT_DIFFICULTY}")"
    echo "[entrypoint] 启用 YaPB 机器人，插件=${YAPB_SO}，数量=${BOT_QUOTA}，阵营=${BOT_JOIN_TEAM}，前缀=${BOT_NAME_PREFIX}，难度=${BOT_DIFFICULTY_LEVEL}"
    echo "${YAPB_LINE}" >> "${METAMOD_PLUGINS}"
    cat > "${BOTS_CFG}" <<EOF
// 由 entrypoint 根据 ENABLE_BOTS 自动生成
yb_quota ${BOT_QUOTA}
yb_join_team ${BOT_JOIN_TEAM}
yb_join_after_player 0
yb_name_prefix "${BOT_NAME_PREFIX}"
yb_difficulty ${BOT_DIFFICULTY_LEVEL}
yb_difficulty_min -1
yb_difficulty_max -1
EOF
    echo "exec bots.cfg" >> "${RUNTIME_CFG}"
  fi
else
  echo "[entrypoint] 未启用机器人（ENABLE_BOTS=${ENABLE_BOTS}）"
fi

# ---------- 启动 HLDS ----------
cd "${HLDS_DIR}"
EXTRA_ARGS=("$@")

exec ./hlds_run \
  -game cstrike \
  -console \
  -port "${PORT}" \
  -timeout 3 \
  -pingboost 2 \
  +ip 0.0.0.0 \
  +maxplayers "${MAXPLAYERS}" \
  +map "${START_MAP}" \
  +sys_ticrate "${TICKRATE}" \
  "${EXTRA_ARGS[@]}"
