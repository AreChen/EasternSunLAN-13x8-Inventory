[CmdletBinding()]
param(
    [string]$ModRoot = "",
    [switch]$NoBackup,
    [switch]$SkipD2RLANSetting,
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[13x8] $Message"
}

function Resolve-TargetRoot {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        $cwd = (Get-Location).Path
        if (Test-Path (Join-Path $cwd "EasternSunLAN.mpq")) {
            return $cwd
        }

        throw "Pass -ModRoot, for example: .\tools\install.ps1 -ModRoot `"H:\D2RLAN\D2R\Mods\EasternSunLAN`""
    }

    return (Resolve-Path -Path $InputPath -ErrorAction Stop).Path
}

function Read-Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path)
}

function Write-Text {
    param(
        [string]$Path,
        [string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Replace-IfNeeded {
    param(
        [string]$Text,
        [string]$Search,
        [string]$Replacement,
        [string]$File
    )

    if ($Text.Contains($Replacement)) {
        return $Text
    }

    if (-not $Text.Contains($Search)) {
        throw "Expected text not found in $File`: $Search"
    }

    return $Text.Replace($Search, $Replacement)
}

function New-TargetPaths {
    param([string]$Root)

    $mpq = Join-Path $Root "EasternSunLAN.mpq"
    return [ordered]@{
        ModRoot = $Root
        MpqRoot = $mpq
        Inventory = Join-Path $mpq "data\global\excel\inventory.txt"
        ProfileHd = Join-Path $mpq "data\global\ui\layouts\_profilehd.json"
        HdLayout = Join-Path $mpq "data\global\ui\layouts\playerinventoryoriginallayouthd.json"
        LegacyLayout = Join-Path $mpq "data\global\ui\layouts\playerinventoryoriginallayout.json"
        ControllerLayout = Join-Path $mpq "data\global\ui\layouts\controller\playerinventoryoriginallayouthd.json"
        D2RLANExpandedTemplate = Join-Path $mpq "data\D2RLAN\Expanded\Inventory\playerinventoryoriginallayouthd_expanded.json"
        UserSettings = Join-Path $mpq "MyUserSettings.json"
    }
}

function Test-RequiredFiles {
    param([hashtable]$Paths)

    foreach ($key in @("Inventory", "ProfileHd", "HdLayout", "LegacyLayout", "ControllerLayout", "D2RLANExpandedTemplate")) {
        if (-not (Test-Path $Paths[$key])) {
            throw "Missing required target file: $($Paths[$key])"
        }
    }
}

function Backup-Files {
    param(
        [hashtable]$Paths,
        [bool]$IncludeSettings
    )

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupRoot = Join-Path $Paths.ModRoot ".backup\13x8-inventory\$stamp"
    $rootPrefix = $Paths.ModRoot.TrimEnd("\") + "\"
    $files = @(
        $Paths.Inventory,
        $Paths.ProfileHd,
        $Paths.HdLayout,
        $Paths.LegacyLayout,
        $Paths.ControllerLayout,
        $Paths.D2RLANExpandedTemplate
    )

    if ($IncludeSettings -and (Test-Path $Paths.UserSettings)) {
        $files += $Paths.UserSettings
    }

    foreach ($file in $files) {
        if (-not (Test-Path $file)) {
            continue
        }

        $relative = $file.Substring($rootPrefix.Length)
        $dest = Join-Path $backupRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item -Path $file -Destination $dest -Force
    }

    Write-Step "Backup created at $backupRoot"
}

function Patch-InventoryTxt {
    param([string]$File)

    $content = Read-Text $File
    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $hasTrailingNewline = $content.EndsWith("`n")
    $lines = [regex]::Split($content.TrimEnd("`r", "`n"), "\r?\n")
    $header = $lines[0] -split "`t"
    $index = @{}

    for ($i = 0; $i -lt $header.Count; $i++) {
        $index[$header[$i]] = $i
    }

    foreach ($column in @("class", "gridX", "gridY")) {
        if (-not $index.ContainsKey($column)) {
            throw "inventory.txt is missing column: $column"
        }
    }

    $classes = @("Amazon", "Assassin", "Barbarian", "Druid", "Necromancer", "Paladin", "Sorceress")
    $changedRows = 0

    for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ([string]::IsNullOrWhiteSpace($lines[$lineIndex])) {
            continue
        }

        $columns = $lines[$lineIndex] -split "`t"
        $className = $columns[$index["class"]]
        $baseClass = if ($className.EndsWith("2")) { $className.Substring(0, $className.Length - 1) } else { $className }

        if ($classes -notcontains $baseClass) {
            continue
        }

        $columns[$index["gridX"]] = "13"
        $columns[$index["gridY"]] = "8"
        $lines[$lineIndex] = $columns -join "`t"
        $changedRows++
    }

    if ($changedRows -ne 14) {
        throw "Expected to update 14 inventory rows, updated $changedRows"
    }

    $updated = $lines -join $newline
    if ($hasTrailingNewline) {
        $updated += $newline
    }

    Write-Text $File $updated
}

function Patch-ProfileHd {
    param([string]$File)

    $text = Read-Text $File

    $rightPanelKey = '"RightPanelRect_ExpandedInventory"'
    if (-not $text.Contains($rightPanelKey)) {
        $search = '    "RightPanelRectI": { "x": -1140, "y": -856, "width": 1562, "height": 1707 },'
        $replacement = $search + "`n" + '    "RightPanelRect_ExpandedInventory": { "x": -1140, "y": -856, "width": 1562, "height": 1707 },'
        $text = Replace-IfNeeded $text $search $replacement $File
    }

    $clickCatcherKey = '"PanelClickCatcherRect_ExpandedInventory"'
    if (-not $text.Contains($clickCatcherKey)) {
        $search = '    "PanelClickCatcherRect": { "x": 0, "y": 0, "width": 1172, "height": 1427 },'
        $replacement = $search + "`n" + '    "PanelClickCatcherRect_ExpandedInventory": { "x": 0, "y": 0, "width": 1562, "height": 1737 },'
        $text = Replace-IfNeeded $text $search $replacement $File
    }

    $hingeKey = '"RightHingeRect_ExpandedInventory"'
    if (-not $text.Contains($hingeKey)) {
        $search = '    "RightHingeRect": { "x": 1076, "y": 630 },'
        $replacement = $search + "`n" + '    "RightHingeRect_ExpandedInventory": { "x": 1076, "y": 630 },'
        $text = Replace-IfNeeded $text $search $replacement $File
    }

    Write-Text $File $text
}

function Patch-HdInventoryLayoutFile {
    param([string]$File)

    $text = Read-Text $File
    $text = Replace-IfNeeded $text ('"rect": "$RightPanelRectI"') ('"rect": "$RightPanelRect_ExpandedInventory"') $File
    $text = Replace-IfNeeded $text ('"rect": "$RightHingeRect"') ('"rect": "$RightHingeRect_ExpandedInventory"') $File
    $text = Replace-IfNeeded $text ('"rect": { "x": 0, "y": 0, "width": 1162, "height": 1737 }') ('"rect": "$PanelClickCatcherRect_ExpandedInventory"') $File
    $text = Replace-IfNeeded $text ('"cellCount": { "x": 10, "y": 8 }') ('"cellCount": { "x": 13, "y": 8 }') $File
    Write-Text $File $text
}

function Patch-LegacyLayout {
    param([string]$File)

    $text = Read-Text $File
    $text = Replace-IfNeeded $text ('"cellCount": { "x": 10, "y": 8 }') ('"cellCount": { "x": 13, "y": 8 }') $File
    Write-Text $File $text
}

function Patch-ControllerLayout {
    param([string]$File)

    $text = Read-Text $File

    if (-not $text.Contains('"cellCount": { "x": 13, "y": 8 }')) {
        $script:ControllerGridInserted = $false
        $pattern = '(\s+"gemSocketFilename": "PANEL/gemsocket",\r?\n)(\s+"navigation": \{)'
        $regex = New-Object regex $pattern
        $text = $regex.Replace($text, {
            param($match)

            if ($script:ControllerGridInserted) {
                return $match.Value
            }

            $script:ControllerGridInserted = $true
            return $match.Groups[1].Value +
                '                "cellCount": { "x": 13, "y": 8 },' + "`n" +
                '                "cellSize": "$ItemCellSize",' + "`n" +
                $match.Groups[2].Value
        })

        if (-not $script:ControllerGridInserted) {
            throw "Could not find the controller grid block for inserting cellCount: $File"
        }

        Remove-Variable -Name ControllerGridInserted -Scope Script -ErrorAction SilentlyContinue
    }

    Write-Text $File $text
}

function Patch-UserSettings {
    param([string]$File)

    if (-not (Test-Path $File)) {
        Write-Step "MyUserSettings.json was not found; skipping D2RLAN setting update"
        return
    }

    $settings = Get-Content -Path $File -Raw | ConvertFrom-Json

    if ($null -eq $settings.PSObject.Properties["ExpandedInventory"]) {
        $settings | Add-Member -NotePropertyName "ExpandedInventory" -NotePropertyValue $true
    } else {
        $settings.ExpandedInventory = $true
    }

    $json = $settings | ConvertTo-Json -Depth 64 -Compress
    Write-Text $File $json

    if ($null -ne $settings.CurrentD2RArgs -and -not ([string]$settings.CurrentD2RArgs).Contains("-txt")) {
        Write-Warning "CurrentD2RArgs does not include -txt. Add -txt to your D2RLAN launch arguments."
    }
}

function Validate-13x8 {
    param(
        [hashtable]$Paths,
        [bool]$CheckSettings
    )

    Test-RequiredFiles $Paths

    $content = Read-Text $Paths.Inventory
    $lines = [regex]::Split($content.TrimEnd("`r", "`n"), "\r?\n")
    $header = $lines[0] -split "`t"
    $index = @{}

    for ($i = 0; $i -lt $header.Count; $i++) {
        $index[$header[$i]] = $i
    }

    foreach ($column in @("class", "gridX", "gridY")) {
        Assert-True $index.ContainsKey($column) "inventory.txt is missing column: $column"
    }

    $classes = @("Amazon", "Assassin", "Barbarian", "Druid", "Necromancer", "Paladin", "Sorceress")
    $seen = 0

    for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ([string]::IsNullOrWhiteSpace($lines[$lineIndex])) {
            continue
        }

        $columns = $lines[$lineIndex] -split "`t"
        $className = $columns[$index["class"]]
        $baseClass = if ($className.EndsWith("2")) { $className.Substring(0, $className.Length - 1) } else { $className }

        if ($classes -notcontains $baseClass) {
            continue
        }

        $seen++
        Assert-True ($columns[$index["gridX"]] -eq "13" -and $columns[$index["gridY"]] -eq "8") "$className is not 13x8"
    }

    Assert-True ($seen -eq 14) "Expected 14 player inventory rows, saw $seen"

    $profile = Read-Text $Paths.ProfileHd
    foreach ($key in @("RightPanelRect_ExpandedInventory", "PanelClickCatcherRect_ExpandedInventory", "RightHingeRect_ExpandedInventory")) {
        Assert-True $profile.Contains("`"$key`"") "_profilehd.json is missing $key"
    }

    $hd = Read-Text $Paths.HdLayout
    $d2rlan = Read-Text $Paths.D2RLANExpandedTemplate

    foreach ($pair in @(@("HD layout", $hd), @("D2RLAN expanded template", $d2rlan))) {
        $name = $pair[0]
        $text = $pair[1]
        Assert-True $text.Contains('"rect": "$RightPanelRect_ExpandedInventory"') "$name does not use expanded inventory panel rect"
        Assert-True $text.Contains('"rect": "$PanelClickCatcherRect_ExpandedInventory"') "$name does not use expanded click catcher rect"
        Assert-True $text.Contains('"cellCount": { "x": 13, "y": 8 }') "$name is not 13x8"
    }

    $legacy = Read-Text $Paths.LegacyLayout
    $controller = Read-Text $Paths.ControllerLayout
    Assert-True $legacy.Contains('"cellCount": { "x": 13, "y": 8 }') "legacy layout is not 13x8"
    Assert-True $controller.Contains('"cellCount": { "x": 13, "y": 8 }') "controller layout is not 13x8"

    $expandedText = $hd + $d2rlan + $legacy + $controller
    Assert-True (-not [regex]::IsMatch($expandedText, '"cellCount"\s*:\s*\{\s*"x"\s*:\s*10\s*,\s*"y"\s*:\s*8\s*\}')) "A 10x8 expanded inventory cellCount remains"
    Assert-True (-not [regex]::IsMatch($expandedText, '"cellCount"\s*:\s*\{\s*"x"\s*:\s*13\s*,\s*"y"\s*:\s*11\s*\}')) "A 13x11 inventory cellCount was introduced"

    if ($CheckSettings -and (Test-Path $Paths.UserSettings)) {
        $settings = Get-Content -Path $Paths.UserSettings -Raw | ConvertFrom-Json
        Assert-True ($settings.ExpandedInventory -eq $true) "ExpandedInventory is not true in MyUserSettings.json"

        if ($null -ne $settings.CurrentD2RArgs -and -not ([string]$settings.CurrentD2RArgs).Contains("-txt")) {
            Write-Warning "CurrentD2RArgs does not include -txt"
        }
    }

    Write-Host "13x8 inventory validation ok"
}

$targetRoot = Resolve-TargetRoot $ModRoot
$paths = New-TargetPaths $targetRoot
Test-RequiredFiles $paths

if ($ValidateOnly) {
    Validate-13x8 $paths (-not $SkipD2RLANSetting)
    exit 0
}

if (-not $NoBackup) {
    Backup-Files $paths (-not $SkipD2RLANSetting)
}

Patch-InventoryTxt $paths.Inventory
Patch-ProfileHd $paths.ProfileHd
Patch-HdInventoryLayoutFile $paths.HdLayout
Patch-HdInventoryLayoutFile $paths.D2RLANExpandedTemplate
Patch-LegacyLayout $paths.LegacyLayout
Patch-ControllerLayout $paths.ControllerLayout

if (-not $SkipD2RLANSetting) {
    Patch-UserSettings $paths.UserSettings
}

Validate-13x8 $paths (-not $SkipD2RLANSetting)
Write-Step "Install complete: EasternSunLAN inventory is now 13x8"
