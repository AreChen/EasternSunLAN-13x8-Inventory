[CmdletBinding()]
param(
    [string]$ModRoot = "",
    [string]$BackupDir = ""
)

$ErrorActionPreference = "Stop"

function Resolve-TargetRoot {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        $cwd = (Get-Location).Path
        if (Test-Path (Join-Path $cwd "EasternSunLAN.mpq")) {
            return $cwd
        }

        throw "Pass -ModRoot, for example: .\tools\uninstall.ps1 -ModRoot `"<D2R>\Mods\EasternSunLAN`""
    }

    return (Resolve-Path -Path $InputPath -ErrorAction Stop).Path
}

$targetRoot = Resolve-TargetRoot $ModRoot

if ([string]::IsNullOrWhiteSpace($BackupDir)) {
    $backupBase = Join-Path $targetRoot ".backup\13x8-inventory"

    if (-not (Test-Path $backupBase)) {
        throw "Backup directory was not found: $backupBase"
    }

    $latest = Get-ChildItem -Path $backupBase -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($null -eq $latest) {
        throw "Backup directory is empty: $backupBase"
    }

    $BackupDir = $latest.FullName
} else {
    $BackupDir = (Resolve-Path -Path $BackupDir -ErrorAction Stop).Path
}

$backupPrefix = $BackupDir.TrimEnd("\") + "\"
$files = Get-ChildItem -Path $BackupDir -Recurse -File

if ($files.Count -eq 0) {
    throw "No restorable files were found in backup directory: $BackupDir"
}

foreach ($file in $files) {
    $relative = $file.FullName.Substring($backupPrefix.Length)
    $target = Join-Path $targetRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Copy-Item -Path $file.FullName -Destination $target -Force
}

Write-Host "[13x8] Restored from backup: $BackupDir"
Write-Host "[13x8] After uninstall, empty the added inventory columns and verify in game."
