#Requires -Version 5.0
# 预下载 HLDS + extras，再构建 cs16-server 镜像
# 用法：powershell -ExecutionPolicy Bypass -File .\scripts\prepare-and-build.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$HldsDir = Join-Path $Root ".cache\hlds"
$PkgDir = Join-Path $Root ".cache\packages"
$HldsTar = Join-Path $Root ".cache\hlds.tar.gz"
$Proxy = if ($env:GITHUB_PROXY) { $env:GITHUB_PROXY } else { "https://ghproxy.net/" }

function Download-File($Url, $OutFile) {
    if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 1000)) {
        Write-Host "  SKIP $(Split-Path $OutFile -Leaf)"
        return
    }
    Write-Host "  DL   $(Split-Path $OutFile -Leaf)"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 300
}

# ---------- 1) HLDS（Windows 无法 docker cp 符号链接，改用 tar） ----------
Write-Host "==> 准备 HLDS ..."
docker rm -f cs16-hlds-prep cs16-pack 2>$null | Out-Null

if (-not (Test-Path (Join-Path $HldsDir "libsteam_api.so"))) {
    Write-Host "  SteamCMD 下载中（需数分钟）..."
    docker run --name cs16-hlds-prep `
        --shm-size=1g `
        --security-opt seccomp=unconfined `
        steamcmd/steamcmd:ubuntu-22 `
        +force_install_dir /data/hlds `
        +login anonymous `
        +app_set_config 90 mod cstrike `
        +app_update 90 -beta steam_legacy `
        +app_update 90 -beta steam_legacy `
        +app_update 90 -beta steam_legacy validate `
        +quit
    if ($LASTEXITCODE -ne 0) { throw "SteamCMD 安装失败" }

    Write-Host "  打包 HLDS（去除损坏的 SDL 链接）..."
    docker commit cs16-hlds-prep cs16-hlds-data:latest | Out-Null
    docker run --name cs16-pack --entrypoint bash cs16-hlds-data:latest -c `
        "rm -f /data/hlds/libSDL2.so; tar -czf /tmp/hlds.tar.gz -C /data/hlds ."
    if ($LASTEXITCODE -ne 0) { throw "打包失败" }

    New-Item -ItemType Directory -Force -Path (Join-Path $Root ".cache") | Out-Null
    docker cp cs16-pack:/tmp/hlds.tar.gz $HldsTar
    docker rm -f cs16-hlds-prep cs16-pack | Out-Null

    Remove-Item -Recurse -Force $HldsDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $HldsDir | Out-Null
    Push-Location $HldsDir
    tar -xzf $HldsTar
    Pop-Location

    if (-not (Test-Path (Join-Path $HldsDir "libsteam_api.so"))) {
        throw "缺少 libsteam_api.so，导出失败"
    }
} else {
    Write-Host "  已存在 .cache/hlds（含 libsteam_api.so），跳过"
}

# ---------- 2) extras ----------
Write-Host "==> 下载 extras 到 .cache/packages ..."
New-Item -ItemType Directory -Force -Path $PkgDir | Out-Null
Download-File "${Proxy}https://github.com/rehlds/ReHLDS/releases/download/3.15.0.896/rehlds-bin-3.15.0.896.zip" (Join-Path $PkgDir "rehlds.zip")
Download-File "${Proxy}https://github.com/rehlds/ReGameDLL_CS/releases/download/5.30.0.814/regamedll-bin-5.30.0.814.zip" (Join-Path $PkgDir "regamedll.zip")
Download-File "${Proxy}https://github.com/rehlds/metamod-r/releases/download/1.3.0.149/metamod-bin-1.3.0.149.zip" (Join-Path $PkgDir "metamod.zip")
Download-File "${Proxy}https://github.com/s1lentq/reapi/releases/download/5.29.0.358/reapi-bin-5.29.0.358.zip" (Join-Path $PkgDir "reapi.zip")
Download-File "${Proxy}https://github.com/rehlds/ReUnion/releases/download/0.2.0.25/reunion-0.2.0.25.zip" (Join-Path $PkgDir "reunion.zip")
Download-File "${Proxy}https://github.com/rehlds/revoice/releases/download/0.1.0.34/revoice_0.1.0.34.zip" (Join-Path $PkgDir "revoice.zip")
Download-File "${Proxy}https://github.com/yapb/yapb/releases/download/4.4.957/yapb-4.4.957-linux.tar.xz" (Join-Path $PkgDir "yapb.tar.xz")
Download-File "https://www.amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5478-base-linux.tar.gz" (Join-Path $PkgDir "amxx-base.tar.gz")
Download-File "https://www.amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5478-cstrike-linux.tar.gz" (Join-Path $PkgDir "amxx-cstrike.tar.gz")

# ---------- 3) build ----------
Write-Host "==> docker build ..."
docker build -t cs16-server .
if ($LASTEXITCODE -ne 0) { throw "docker build 失败" }

Write-Host "==> 完成"
docker images cs16-server
