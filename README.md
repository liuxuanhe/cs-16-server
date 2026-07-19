# CS 1.6 Docker 服务器

基于 **ReHLDS** 栈的 Counter-Strike 1.6 专用服务器，支持自定义地图与机器人开关，可部署到阿里云 ECS。

镜像采用 **多阶段构建 + HLDS 精简**（去掉半条命单机地图/音效/媒体、客户端 DLL、AMXX 编译器、SteamCMD 运行时等）。  
当前镜像约 **650MB**（优化前约 1.47GB）。  

**注意区分：**
- `docker images` → **磁盘镜像大小**
- `docker stats` → **运行内存**（空闲约 70–100MB）

## 包含组件

| 组件 | 作用 |
|------|------|
| SteamCMD + HLDS cstrike | 游戏资源 |
| ReHLDS | 引擎 |
| ReGameDLL_CS | CS 玩法 |
| Metamod-R | 插件加载 |
| AMX Mod X | 管理 / 投票等 |
| ReUnion | Steam + 非 Steam 客户端一起玩 |
| ReVoice | Steam / 非 Steam 语音互通 |
| YaPB | 机器人（默认关闭，可环境变量开启） |

## 快速开始

### Linux / 阿里云 ECS（推荐）

```bash
# 1. 准备依赖镜像（国内可选镜像加速）
docker pull docker.m.daocloud.io/steamcmd/steamcmd:ubuntu-22
docker tag docker.m.daocloud.io/steamcmd/steamcmd:ubuntu-22 steamcmd/steamcmd:ubuntu-22

# 2. 一键准备 HLDS + extras 并构建
#    或按 scripts/prepare-and-build.ps1 中的步骤用 bash 等效执行
docker run --name cs16-hlds-prep --shm-size=1g \
  steamcmd/steamcmd:ubuntu-22 \
  +force_install_dir /data/hlds +login anonymous \
  +app_set_config 90 mod cstrike \
  +app_update 90 -beta steam_legacy validate +quit
docker commit cs16-hlds-prep cs16-hlds-data:latest
docker run --name cs16-pack --entrypoint bash cs16-hlds-data:latest \
  -c "rm -f /data/hlds/libSDL2.so; tar -czf /tmp/hlds.tar.gz -C /data/hlds ."
mkdir -p .cache/hlds .cache/packages
docker cp cs16-pack:/tmp/hlds.tar.gz .cache/hlds.tar.gz
tar -xzf .cache/hlds.tar.gz -C .cache/hlds
docker rm -f cs16-hlds-prep cs16-pack

# 下载 extras 后：
docker build -t cs16-server .
```

Windows 下直接运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-and-build.ps1
```

> Windows Docker 注意：`docker build` 内无法跑 SteamCMD（线程限制），必须先用脚本预下载到 `.cache/`。

### 启动

```bash
docker run -d --name cs16 \
  --shm-size=1g \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  -v "$(pwd)/maps:/opt/steam/custom_maps" \
  -e SERVER_NAME="我们的CS1.6服务器" \
  -e RCON_PASSWORD="请改成强密码" \
  -e START_MAP="de_dust2" \
  -e MAXPLAYERS="16" \
  -e ENABLE_BOTS=0 \
  -e ADMIN_NAME="XuanHe" \
  -e ADMIN_PASSWORD="请改成强密码" \
  cs16-server
```

Windows Docker 若启动异常，可加：`--security-opt seccomp=unconfined`

### Compose

```bash
docker compose up -d
```

### 客户端连接

```text
connect 你的公网IP:27015
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SERVER_NAME` | `CS 1.6 Server` | 服务器名称 |
| `RCON_PASSWORD` | `changeme` | RCON 远程管理密码 |
| `SERVER_PASSWORD` | 空 | 进服密码；空=公开 |
| `START_MAP` | `de_dust2` | 启动地图（不要带 `.bsp`） |
| `MAXPLAYERS` | `16` | 最大人数 |
| `TICKRATE` | `100` | `sys_ticrate` |
| `START_MONEY` | `800` | 初始金钱 `mp_startmoney`（上限一般为 `16000`） |
| `PORT` | `27015` | 容器内监听端口 |
| `ENABLE_BOTS` | `0` | `1` 启用 YaPB；`0` 不加载 |
| `BOT_QUOTA` | `4` | 机器人数量（仅启用时生效） |
| `BOT_JOIN_TEAM` | `any` | 阵营：`any` / `t` / `ct` |
| `BOT_NAME_PREFIX` | 空 | 机器人名字前缀（如 `[XuanHe]` → `[XuanHe] XXXXX`；YaPB 会自动加空格） |
| `BOT_DIFFICULTY` | `0` | 难度：`0`简单 / `1`普通 / `2`中等 / `3`困难 / `4`变态（也可用 `easy`/`hard`/`godlike`） |
| `ADMIN_NAME` | 空 | AMXX 管理员游戏名（配合 `ADMIN_PASSWORD`） |
| `ADMIN_PASSWORD` | 空 | AMXX 管理员密码（`setinfo _pw`） |
| `ADMIN_STEAMID` | 空 | 可选；SteamID 管理员（如 `STEAM_0:1:xxxx`） |
| `ADMIN_FLAGS` | `abcdefghijklmnopqrstu` | AMXX 权限字母 |

## 游戏内管理员（AMXX）

1. 在 `docker-compose.yml` 设置 `ADMIN_NAME` / `ADMIN_PASSWORD`（或 `ADMIN_STEAMID`）
2. `docker compose up -d` 后进服
3. **进服前**在控制台设置密码（必须带引号），再 `connect`：
   ```text
   setinfo _pw "36184416"
   connect 你的IP:27015
   ```
   进服后再设无效。也可写入客户端 `cstrike/userconfig.cfg` 永久保存。
4. 打开管理菜单：
   ```text
   amxmodmenu
   ```
   或按默认绑定键（常见为 `=` / `m`，以客户端为准）

菜单可换图、踢人、封禁、投票、改部分 cvar 等。加机器人需先 `ENABLE_BOTS=1`，再在菜单/控制台调整 `yb_quota`。

> 游戏名必须与 `ADMIN_NAME` 完全一致（当前为 `XuanHe`）。密码错误不会踢人，只是没有管理员权限。

## 中文提示与进服介绍

- AMXX 默认语言已设为简体中文（`config/amxx_chinese.cfg`）
- 进服 MOTD 来自 [`config/server_info.html`](config/server_info.html)，可自行改文案
- Compose 已挂载 `./config` → 改完后 `docker compose up -d` 重建容器即可生效（不必 rebuild 镜像）

> 说明：炸弹安放、回合开始等**引擎 HUD 文本**由客户端语言决定；服务器侧 AMXX 提示、滚动条、中央公告、MOTD 为中文。

## 自定义地图

1. 把 `.bsp`（及 `.wad` 等）放进 `maps/`
2. 挂载：`-v "$(pwd)/maps:/opt/steam/custom_maps"`
3. 启动：`-e START_MAP=我的地图名`

## 阿里云 ECS

1. x86_64 实例，至少 1 核 1G（开机器人建议 2 核）
2. 安全组放行 **UDP 27015**（必须）、**TCP 27015**（建议）
3. 构建并启动后，客户端：`connect 公网IP:27015`

```bash
docker logs -f cs16
```

## 目录说明

```text
.
├── Dockerfile
├── entrypoint.sh              # 启动脚本（地图 / 机器人 / Admin / 中文）
├── docker-compose.yml
├── config/
│   ├── server.cfg             # 主配置
│   ├── server_info.html       # 进服介绍 MOTD（中文）
│   ├── amxx_chinese.cfg       # AMXX 中文提示
│   ├── users.ini              # AMXX 管理员模板
│   └── mapcycle.txt
├── maps/                      # 自定义地图
├── scripts/
│   ├── prepare-and-build.ps1  # Windows 一键准备+构建
│   ├── hlds.install
│   └── 99apt-fix.conf
└── .cache/                    # 本地缓存（不入库）：hlds + packages
```

## 常见问题

**连不上**  
检查安全组 UDP 27015、容器是否 `Up`：`docker ps` / `docker logs cs16`。

**打不开 amxmodmenu / 提示无权限**  
确认 `ADMIN_NAME` 与游戏内昵称完全一致，并已执行 `setinfo _pw 密码`；或配置 `ADMIN_STEAMID`。查看日志：`docker logs cs16-server` 应出现 `AMXX Admin`。

**MOTD / 中文改了不生效**  
改的是 `./config/` 时执行 `docker compose up -d`（重建容器）。若只改了镜像内文件，需要 `--build`。

**Windows 构建失败 / SteamCMD 卡死**  
使用 `scripts\prepare-and-build.ps1`，不要直接在 `Dockerfile` 里跑 SteamCMD。

**缺少 libsteam_api.so**  
说明 `.cache/hlds` 不完整，删除后重新跑准备脚本（必须用 tar 导出，不能直接 `docker cp` 目录）。
