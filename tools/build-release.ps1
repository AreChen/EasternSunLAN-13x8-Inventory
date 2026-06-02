[CmdletBinding()]
param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot "..")
$repoRoot = $repoRoot.Path

if ([string]::IsNullOrWhiteSpace($Version)) {
    $pluginInfo = Get-Content -Path (Join-Path $repoRoot "plugininfo.json") -Raw | ConvertFrom-Json
    $Version = $pluginInfo.version
}

$dist = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$safeVersion = $Version.Trim()
$archive = Join-Path $dist "EasternSunLAN-13x8-Inventory-$safeVersion.zip"
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("EasternSunLAN-13x8-Inventory-" + [guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $stage | Out-Null

foreach ($item in @("README.md", "CHANGELOG.md", "LICENSE", "NOTICE.md", "plugininfo.json")) {
    Copy-Item -Path (Join-Path $repoRoot $item) -Destination (Join-Path $stage $item) -Force
}

Copy-Item -Path (Join-Path $repoRoot "docs") -Destination (Join-Path $stage "docs") -Recurse -Force
Copy-Item -Path (Join-Path $repoRoot "tools") -Destination (Join-Path $stage "tools") -Recurse -Force
Copy-Item -Path (Join-Path $repoRoot "overlay") -Destination (Join-Path $stage "overlay") -Recurse -Force

if (Test-Path $archive) {
    Remove-Item -Path $archive -Force
}

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $archive -Force
Remove-Item -Path $stage -Recurse -Force

Write-Host $archive
