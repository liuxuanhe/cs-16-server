param(
    [Parameter(Mandatory = $true)][string]$VdfPath,
    [Parameter(Mandatory = $true)][string]$ServerName,
    [Parameter(Mandatory = $true)][string]$ServerAddress
)

$ErrorActionPreference = "Stop"

try {
    $dir = Split-Path -Parent $VdfPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $VdfPath) {
        try { Set-ItemProperty -LiteralPath $VdfPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue } catch {}
        Copy-Item -LiteralPath $VdfPath -Destination ($VdfPath + ".bak") -Force
    }

    # Match Chinese non-Steam CS format (platform\config\ServerBrowser.vdf):
    # LF newlines + trailing NUL + full FilterList
    $nl = "`n"
    $content = @(
        '"Filters"',
        '{',
        "`t`"Favorites`"",
        "`t{",
        "`t`t`"1`"",
        "`t`t{",
        "`t`t`t`"name`"`t`t`"$ServerName`"",
        "`t`t`t`"players`"`t`t`"0`"",
        "`t`t`t`"maxplayers`"`t`t`"0`"",
        "`t`t`t`"address`"`t`t`"$ServerAddress`"",
        "`t`t`t`"lastplayed`"`t`t`"0`"",
        "`t`t`t`"secure`"`t`t`"0`"",
        "`t`t`t`"type`"`t`t`"0`"",
        "`t`t}",
        "`t}",
        "`t`"FilterList`"",
        "`t{",
        "`t`t`"InternetGames`"",
        "`t`t{",
        "`t`t`t`"ping`"`t`t`"0`"",
        "`t`t`t`"location`"`t`t`"0`"",
        "`t`t`t`"NoFull`"`t`t`"0`"",
        "`t`t`t`"NoEmpty`"`t`t`"0`"",
        "`t`t`t`"NoPassword`"`t`t`"0`"",
        "`t`t`t`"secure`"`t`t`"0`"",
        "`t`t`t`"lastquery`"`t`t`"0`"",
        "`t`t}",
        "`t`t`"SpectateGames`"",
        "`t`t{",
        "`t`t`t`"ping`"`t`t`"0`"",
        "`t`t`t`"location`"`t`t`"0`"",
        "`t`t`t`"NoFull`"`t`t`"0`"",
        "`t`t`t`"NoEmpty`"`t`t`"0`"",
        "`t`t`t`"NoPassword`"`t`t`"0`"",
        "`t`t`t`"secure`"`t`t`"0`"",
        "`t`t`t`"lastquery`"`t`t`"0`"",
        "`t`t}",
        "`t`t`"FavoriteGames`"",
        "`t`t{",
        "`t`t`t`"ping`"`t`t`"0`"",
        "`t`t`t`"NoFull`"`t`t`"0`"",
        "`t`t`t`"NoEmpty`"`t`t`"0`"",
        "`t`t`t`"NoPassword`"`t`t`"0`"",
        "`t`t`t`"secure`"`t`t`"0`"",
        "`t`t}",
        "`t`t`"LanGames`"",
        "`t`t{",
        "`t`t`t`"ping`"`t`t`"0`"",
        "`t`t`t`"NoFull`"`t`t`"0`"",
        "`t`t`t`"NoEmpty`"`t`t`"0`"",
        "`t`t`t`"NoPassword`"`t`t`"0`"",
        "`t`t`t`"secure`"`t`t`"0`"",
        "`t`t}",
        "`t`t`"FriendsGames`"",
        "`t`t{",
        "`t`t`t`"ping`"`t`t`"0`"",
        "`t`t`t`"NoFull`"`t`t`"0`"",
        "`t`t`t`"NoEmpty`"`t`t`"0`"",
        "`t`t`t`"NoPassword`"`t`t`"0`"",
        "`t`t`t`"secure`"`t`t`"0`"",
        "`t`t}",
        "`t`t`"HistoryGames`"",
        "`t`t{",
        "`t`t`t`"ping`"`t`t`"0`"",
        "`t`t`t`"NoFull`"`t`t`"0`"",
        "`t`t`t`"NoEmpty`"`t`t`"0`"",
        "`t`t`t`"NoPassword`"`t`t`"0`"",
        "`t`t`t`"secure`"`t`t`"0`"",
        "`t`t}",
        "`t}",
        "`t`"gamelist`"`t`t`"favorites`"",
        '}'
    ) -join $nl
    $content = $content + $nl

    $enc = [System.Text.Encoding]::GetEncoding(1252)
    $bytes = $enc.GetBytes($content) + [byte]0
    [System.IO.File]::WriteAllBytes($VdfPath, $bytes)
    Write-Host "OK"
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
