# ============================================================
# CS 1.6 专用服务器镜像（ReHLDS 栈，多阶段精简）
#
# 构建前：powershell -ExecutionPolicy Bypass -File .\scripts\prepare-and-build.ps1
# 或确保已有 .cache/hlds 与 .cache/packages
# ============================================================

# ---------- stage 1: 组装并精简游戏文件 ----------
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

COPY scripts/99apt-fix.conf /etc/apt/apt.conf.d/99apt-fix.conf
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list \
    && sed -i 's|http://security.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends unzip xz-utils findutils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY .cache/hlds /opt/steam/hlds
COPY .cache/packages /tmp/packages
COPY scripts/strip-hlds.sh /tmp/strip-hlds.sh

WORKDIR /opt/steam/hlds
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test -x /opt/steam/hlds/hlds_run \
    && sed -i 's/\r$//' /tmp/strip-hlds.sh \
    && chmod +x /opt/steam/hlds/hlds_run /opt/steam/hlds/hlds_linux /tmp/strip-hlds.sh || true

# ReHLDS
RUN unzip -o /tmp/packages/rehlds.zip -d /tmp/rehlds \
    && cp -rf /tmp/rehlds/bin/linux32/* /opt/steam/hlds/ \
    && rm -rf /tmp/rehlds

# ReGameDLL_CS
RUN unzip -o /tmp/packages/regamedll.zip -d /tmp/regamedll \
    && cp -rf /tmp/regamedll/bin/linux32/cstrike/* /opt/steam/hlds/cstrike/ \
    && rm -rf /tmp/regamedll

# Metamod-R
RUN mkdir -p /opt/steam/hlds/cstrike/addons/metamod \
    && unzip -o /tmp/packages/metamod.zip -d /tmp/metamod \
    && if [ -d /tmp/metamod/addons/metamod ]; then \
         cp -rf /tmp/metamod/addons/metamod/* /opt/steam/hlds/cstrike/addons/metamod/; \
       else \
         find /tmp/metamod -name 'metamod*.so' -exec cp {} /opt/steam/hlds/cstrike/addons/metamod/ \; ; \
       fi \
    && touch /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    && METAMOD_SO="$(find /opt/steam/hlds/cstrike/addons/metamod -maxdepth 1 -name 'metamod*.so' | head -n 1 | xargs -r basename)" \
    && test -n "${METAMOD_SO}" \
    && (grep -q 'gamedll_linux' /opt/steam/hlds/cstrike/liblist.gam \
        && sed -i "s|gamedll_linux.*|gamedll_linux \"addons/metamod/${METAMOD_SO}\"|" /opt/steam/hlds/cstrike/liblist.gam \
        || echo "gamedll_linux \"addons/metamod/${METAMOD_SO}\"" >> /opt/steam/hlds/cstrike/liblist.gam) \
    && rm -rf /tmp/metamod

# AMX Mod X
RUN tar -C /opt/steam/hlds/cstrike/ -zxf /tmp/packages/amxx-base.tar.gz \
    && tar -C /opt/steam/hlds/cstrike/ -zxf /tmp/packages/amxx-cstrike.tar.gz \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    && cat /opt/steam/hlds/cstrike/mapcycle.txt >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/maps.ini || true

# ReAPI
RUN unzip -o /tmp/packages/reapi.zip -d /tmp/reapi \
    && cp -rf /tmp/reapi/addons /opt/steam/hlds/cstrike/ 2>/dev/null || true \
    && if ! grep -q '^reapi' /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini 2>/dev/null; then \
         echo 'reapi' >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini; \
       fi \
    && rm -rf /tmp/reapi

# ReUnion
RUN mkdir -p /opt/steam/hlds/cstrike/addons/reunion \
    && unzip -o /tmp/packages/reunion.zip -d /tmp/reunion \
    && find /tmp/reunion -name 'reunion_mm_i386.so' -exec cp {} /opt/steam/hlds/cstrike/addons/reunion/ \; \
    && find /tmp/reunion -name 'reunion.cfg' -exec cp {} /opt/steam/hlds/cstrike/ \; \
    && { echo 'linux addons/reunion/reunion_mm_i386.so'; cat /opt/steam/hlds/cstrike/addons/metamod/plugins.ini; } \
        > /tmp/plugins.ini.new \
    && mv /tmp/plugins.ini.new /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    && rm -rf /tmp/reunion

# ReVoice
RUN mkdir -p /opt/steam/hlds/cstrike/addons/revoice \
    && unzip -o /tmp/packages/revoice.zip -d /tmp/revoice \
    && find /tmp/revoice -name 'revoice_mm_i386.so' -exec cp {} /opt/steam/hlds/cstrike/addons/revoice/ \; \
    && find /tmp/revoice -name 'revoice.cfg' -exec cp {} /opt/steam/hlds/cstrike/addons/revoice/ \; \
    && echo 'linux addons/revoice/revoice_mm_i386.so' >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    && rm -rf /tmp/revoice

# YaPB
RUN tar -xJf /tmp/packages/yapb.tar.xz -C /opt/steam/hlds/cstrike/ \
    && rm -rf /tmp/packages

RUN touch /opt/steam/hlds/cstrike/listip.cfg \
    && touch /opt/steam/hlds/cstrike/banned.cfg \
    && echo 10 > /opt/steam/hlds/steam_appid.txt \
    && chmod +x /opt/steam/hlds/hlds_run /opt/steam/hlds/hlds_linux || true \
    && /tmp/strip-hlds.sh /opt/steam/hlds

COPY config/server.cfg /opt/steam/hlds/cstrike/server.cfg.default
COPY config/server.cfg /opt/steam/hlds/cstrike/server.cfg
COPY config/mapcycle.txt /opt/steam/hlds/cstrike/mapcycle.txt
COPY config/banned.cfg /opt/steam/hlds/cstrike/banned.cfg
COPY config/listip.cfg /opt/steam/hlds/cstrike/listip.cfg
COPY config/reunion.cfg /opt/steam/hlds/cstrike/reunion.cfg
COPY config/server_info.html /opt/steam/hlds/cstrike/server_info.html
COPY config/amxx_chinese.cfg /opt/steam/hlds/cstrike/addons/amxmodx/configs/amxx_chinese.cfg
COPY config/users.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/users.ini

RUN mkdir -p /opt/steam/defaults \
    && cp -f /opt/steam/hlds/cstrike/reunion.cfg /opt/steam/defaults/ \
    && cp -f /opt/steam/hlds/cstrike/server_info.html /opt/steam/defaults/ \
    && cp -f /opt/steam/hlds/cstrike/addons/amxmodx/configs/amxx_chinese.cfg /opt/steam/defaults/ \
    && cp -f /opt/steam/hlds/cstrike/addons/amxmodx/configs/users.ini /opt/steam/defaults/

# ---------- stage 2: 精简运行时 ----------
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    CPU_MHZ=2300 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    SERVER_NAME="CS 1.6 Server" \
    RCON_PASSWORD="changeme" \
    SERVER_PASSWORD="" \
    START_MAP="de_dust2" \
    MAXPLAYERS="16" \
    TICKRATE="100" \
    START_MONEY="800" \
    PORT="27015" \
    ENABLE_BOTS="0" \
    BOT_QUOTA="4" \
    BOT_JOIN_TEAM="any" \
    BOT_NAME_PREFIX="" \
    BOT_DIFFICULTY="0" \
    ADMIN_NAME="" \
    ADMIN_PASSWORD="" \
    ADMIN_STEAMID="" \
    ADMIN_FLAGS="abcdefghijklmnopqrstu"

COPY scripts/99apt-fix.conf /etc/apt/apt.conf.d/99apt-fix.conf
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list \
    && sed -i 's|http://security.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        lib32gcc-s1 \
        lib32stdc++6 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/steam/config_src /root/.steam \
    && ln -sfn /opt/steam/hlds /root/.steam/sdk32

COPY --from=builder /opt/steam /opt/steam
COPY entrypoint.sh /opt/steam/entrypoint.sh
RUN chmod +x /opt/steam/entrypoint.sh \
    && chmod +x /opt/steam/hlds/hlds_run /opt/steam/hlds/hlds_linux || true

WORKDIR /opt/steam/hlds
EXPOSE 27015/tcp
EXPOSE 27015/udp
VOLUME ["/opt/steam/custom_maps", "/opt/steam/config_src"]
ENTRYPOINT ["/opt/steam/entrypoint.sh"]
