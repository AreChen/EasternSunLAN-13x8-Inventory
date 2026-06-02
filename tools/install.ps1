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

        throw "Pass -ModRoot, for example: .\tools\install.ps1 -ModRoot `"<D2R>\Mods\EasternSunLAN`""
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

function Replace-AnyIfNeeded {
    param(
        [string]$Text,
        [string[]]$Searches,
        [string]$Replacement,
        [string]$File
    )

    if ($Text.Contains($Replacement)) {
        return $Text
    }

    foreach ($search in $Searches) {
        if ($Text.Contains($search)) {
            return $Text.Replace($search, $Replacement)
        }
    }

    throw "Expected text not found in $File`: $Replacement"
}

function Set-ObjectLine {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Value,
        [string]$AfterLine,
        [string]$File
    )

    $line = '    "' + $Key + '": ' + $Value + ','
    $pattern = '(?m)^\s*"' + [regex]::Escape($Key) + '"\s*:\s*\{[^\r\n]*\},\s*$'

    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, $line, 1)
    }

    return Replace-IfNeeded $Text $AfterLine ($AfterLine + "`n" + $line) $File
}

function New-TargetPaths {
    param([string]$Root)

    $mpq = Join-Path $Root "EasternSunLAN.mpq"
    return [ordered]@{
        ModRoot = $Root
        MpqRoot = $mpq
        Inventory = Join-Path $mpq "data\global\excel\inventory.txt"
        ProfileHd = Join-Path $mpq "data\global\ui\layouts\_profilehd.json"
        ProfileLv = Join-Path $mpq "data\global\ui\layouts\_profilelv.json"
        HdLayout = Join-Path $mpq "data\global\ui\layouts\playerinventoryoriginallayouthd.json"
        LegacyLayout = Join-Path $mpq "data\global\ui\layouts\playerinventoryoriginallayout.json"
        ControllerLayout = Join-Path $mpq "data\global\ui\layouts\controller\playerinventoryoriginallayouthd.json"
        D2RLANExpandedTemplate = Join-Path $mpq "data\D2RLAN\Expanded\Inventory\playerinventoryoriginallayouthd_expanded.json"
        D2RLANExpansionTemplate = Join-Path $mpq "data\D2RLAN\Expanded\Inventory\playerinventoryexpansionlayouthd_expanded.json"
        HdExpansionLayout = Join-Path $mpq "data\global\ui\layouts\playerinventoryexpansionlayouthd.json"
        ControllerExpansionLayout = Join-Path $mpq "data\global\ui\layouts\controller\playerinventoryexpansionlayouthd.json"
        UserSettings = Join-Path $mpq "MyUserSettings.json"
    }
}

function Test-RequiredFiles {
    param([hashtable]$Paths)

    foreach ($key in @("Inventory", "ProfileHd", "ProfileLv", "HdLayout", "LegacyLayout", "ControllerLayout", "D2RLANExpandedTemplate", "D2RLANExpansionTemplate", "HdExpansionLayout", "ControllerExpansionLayout")) {
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
        $Paths.ProfileLv,
        $Paths.HdLayout,
        $Paths.LegacyLayout,
        $Paths.ControllerLayout,
        $Paths.D2RLANExpandedTemplate,
        $Paths.D2RLANExpansionTemplate,
        $Paths.HdExpansionLayout,
        $Paths.ControllerExpansionLayout
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

function Copy-OverlayAssets {
    param([hashtable]$Paths)

    $repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot "..")
    $overlayMpq = Join-Path $repoRoot.Path "overlay\EasternSunLAN.mpq"

    if (-not (Test-Path $overlayMpq)) {
        throw "Overlay assets were not found: $overlayMpq"
    }

    Copy-Item -Path (Join-Path $overlayMpq "data\hd") -Destination (Join-Path $Paths.MpqRoot "data") -Recurse -Force
    Write-Step "Copied 13x8 HD inventory art overlay"
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

    $text = Set-ObjectLine $text "RightPanelRect_ExpandedInventory" '{ "x": -1140, "y": -856, "width": 1562, "height": 1707 }' '    "RightPanelRectI": { "x": -1140, "y": -856, "width": 1562, "height": 1707 },' $File
    $text = Set-ObjectLine $text "PanelClickCatcherRect_ExpandedInventory" '{ "x": 0, "y": 0, "width": 1562, "height": 1737 }' '    "PanelClickCatcherRect": { "x": 0, "y": 0, "width": 1172, "height": 1427 },' $File
    $text = Set-ObjectLine $text "RightHingeRect" '{ "x": 1076, "y": 630 }' '    "RightSideHoverOffset": { "x": -1086, "y": 0 },' $File
    $text = Set-ObjectLine $text "RightHingeRect_ExpandedInventory" '{ "x": 1076, "y": 630 }' '    "RightHingeRect": { "x": 1076, "y": 630 },' $File

    Write-Text $File $text
}

function Patch-ProfileLv {
    param([string]$File)

    $text = Read-Text $File
    $text = Set-ObjectLine $text "RightPanelRect_ExpandedInventory" '{ "x": -1346, "y": 0, "width": 1162, "height": 1737, "scale": 1.16 }' '    "RightPanelRect":  { "x": -1346, "y": -856, "width": 1162, "height": 1507, "scale": 1.16 },' $File
    Write-Text $File $text
}

function Patch-InventoryOriginalHdArt {
    param([string]$File)

    $text = Read-Text $File
    $text = Replace-AnyIfNeeded $text @('"rect": "$RightPanelRectI"', '"rect": "$RightPanelRect_ExpandedInventory"') '"rect": "$RightPanelRect_ExpandedInventory"' $File
    $text = Replace-AnyIfNeeded $text @('"rect": "$RightHingeRect"', '"rect": "$RightHingeRect_ExpandedInventory"') '"rect": "$RightHingeRect_ExpandedInventory"' $File
    $text = Replace-AnyIfNeeded $text @('"rect": { "x": 0, "y": 0, "width": 1162, "height": 1737 }', '"rect": "$PanelClickCatcherRect_ExpandedInventory"', '"rect": { "x": 0, "y": 45, "width": 1093, "height": 1495 }') '"rect": "$PanelClickCatcherRect_ExpandedInventory"' $File
    $text = Replace-AnyIfNeeded $text @('"filename": "PANEL\\Inventory\\Background_Expanded2"', '"filename": "PANEL\\Inventory\\Classic_Background_Expanded"') '"filename": "PANEL\\Inventory\\Background_Expanded2"' $File
    $text = Replace-AnyIfNeeded $text @('"rect": { "x": 1080, "y": 1 }', '"rect": { "x": 1300, "y": 1 }') '"rect": { "x": 1080, "y": 1 }' $File
    $text = Replace-AnyIfNeeded $text @('"rect": { "x": 93, "y": 819 }', '"rect": { "x": 56, "y": 590 }', '"rect": { "x": 56, "y": 640 }') '"rect": { "x": 93, "y": 819 }' $File
    $text = Replace-AnyIfNeeded $text @('"cellCount": { "x": 10, "y": 8 }', '"cellCount": { "x": 13, "y": 8 }') '"cellCount": { "x": 13, "y": 8 }' $File

    $rects = @(
        @('"rect": { "x": 482, "y": 105, "width": 196, "height": 196 }', '"rect": { "x": 338, "y": 117, "width": 196, "height": 196 }', '"rect": { "x": 338, "y": 169, "width": 196, "height": 196 }'),
        @('"rect": { "x": 718, "y": 273, "width": 98, "height": 98 }', '"rect": { "x": 817, "y": 91, "width": 98, "height": 98 }', '"rect": { "x": 817, "y": 143, "width": 98, "height": 98 }'),
        @('"rect": { "x": 482, "y": 348, "width": 196, "height": 294 }', '"rect": { "x": 583, "y": 119, "width": 196, "height": 294 }', '"rect": { "x": 583, "y": 171, "width": 196, "height": 294 }'),
        @('"rect": { "x": 109, "y": 152, "width": 196, "height": 392 }', '"rect": { "x": 95, "y": 164, "width": 196, "height": 392 }', '"rect": { "x": 94, "y": 216, "width": 196, "height": 392 }'),
        @('"rect": { "x": 861, "y": 152, "width": 196, "height": 392 }', '"rect": { "x": 1088, "y": 164, "width": 196, "height": 392 }', '"rect": { "x": 1087, "y": 216, "width": 196, "height": 392 }'),
        @('"rect": { "x": 344, "y": 690, "width": 98, "height": 98 }', '"rect": { "x": 818, "y": 224, "width": 98, "height": 98 }', '"rect": { "x": 818, "y": 276, "width": 98, "height": 98 }'),
        @('"rect": { "x": 718, "y": 689, "width": 98, "height": 98 }', '"rect": { "x": 950, "y": 223, "width": 98, "height": 98 }', '"rect": { "x": 950, "y": 276, "width": 98, "height": 98 }'),
        @('"rect": { "x": 483, "y": 689, "width": 196, "height": 98 }', '"rect": { "x": 584, "y": 455, "width": 196, "height": 98 }', '"rect": { "x": 584, "y": 507, "width": 196, "height": 98 }'),
        @('"rect": { "x": 860, "y": 588, "width": 196, "height": 196 }', '"rect": { "x": 834, "y": 357, "width": 196, "height": 196 }', '"rect": { "x": 833, "y": 413, "width": 196, "height": 196 }'),
        @('"rect": { "x": 107, "y": 588, "width": 196, "height": 196 }', '"rect": { "x": 338, "y": 355, "width": 196, "height": 196 }', '"rect": { "x": 338, "y": 411, "width": 196, "height": 196 }')
    )

    foreach ($pair in $rects) {
        $text = Replace-AnyIfNeeded $text @($pair[0], $pair[1], $pair[2]) $pair[0] $File
    }

    Write-Text $File $text
}

function Patch-InventoryExpansionHdArt {
    param([string]$File)

    $text = Read-Text $File
    $text = Replace-AnyIfNeeded $text @('"filename": "PANEL\\Inventory\\Background_Expanded2"', '"filename": "PANEL\\Inventory\\Background_Expanded"') '"filename": "PANEL\\Inventory\\Background_Expanded2"' $File

    $rects = @(
        @('"rect": { "x": 99, "y": 100 }', '"rect": { "x": 85, "y": 112 }', '"rect": { "x": 85, "y": 191 }'),
        @('"rect": { "x": 850, "y": 100 }', '"rect": { "x": 1077, "y": 112 }', '"rect": { "x": 1077, "y": 191 }'),
        @('"rect": { "x": 99, "y": 100, "width": 107, "height": 48 }', '"rect": { "x": 85, "y": 112, "width": 107, "height": 48 }', '"rect": { "x": 85, "y": 192, "width": 107, "height": 48 }'),
        @('"rect": { "x": 205, "y": 100, "width": 107, "height": 48 }', '"rect": { "x": 191, "y": 112, "width": 107, "height": 48 }', '"rect": { "x": 191, "y": 192, "width": 107, "height": 48 }'),
        @('"rect": { "x": 850, "y": 100, "width": 107, "height": 48 }', '"rect": { "x": 1077, "y": 112, "width": 107, "height": 48 }', '"rect": { "x": 1077, "y": 192, "width": 107, "height": 48 }'),
        @('"rect": { "x": 956, "y": 100, "width": 107, "height": 48 }', '"rect": { "x": 1183, "y": 112, "width": 107, "height": 48 }', '"rect": { "x": 1183, "y": 192, "width": 107, "height": 48 }'),
        @('"rect": { "x": 99, "y": 100, "width": 215, "height": 48 }', '"rect": { "x": 85, "y": 112, "width": 215, "height": 48 }', '"rect": { "x": 85, "y": 191, "width": 215, "height": 48 }'),
        @('"rect": { "x": 850, "y": 100, "width": 215, "height": 48 }', '"rect": { "x": 1077, "y": 112, "width": 215, "height": 48 }', '"rect": { "x": 1077, "y": 191, "width": 215, "height": 48 }')
    )

    foreach ($pair in $rects) {
        $text = Replace-AnyIfNeeded $text @($pair[0], $pair[1], $pair[2]) $pair[0] $File
    }

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
    $text = Replace-AnyIfNeeded $text @('"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Edit"', '"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Classic_Expanded"') '"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Classic_Expanded"' $File
    $text = Replace-AnyIfNeeded $text @('"rect":{"x":-508, "y":-700}', '"rect":{"x":-674, "y":-860}') '"rect":{"x":-674, "y":-860}' $File
    $text = Replace-AnyIfNeeded $text @('"rect": { "x": 216, "y": 893}', '"rect": { "x": 84, "y": 549}') '"rect": { "x": 84, "y": 549}' $File

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

    $rects = @(
        @('"rect": { "x": 607, "y": 59, "width": 196, "height": 196 }', '"rect": { "x": 368, "y": 80, "width": 196, "height": 196 }'),
        @('"rect": { "x": 851, "y": 221, "width": 98, "height": 98 }', '"rect": { "x": 848, "y": 54, "width": 98, "height": 98 }'),
        @('"rect": { "x": 607, "y": 281, "width": 196, "height": 294 }', '"rect": { "x": 613, "y": 82, "width": 196, "height": 294 }'),
        @('"rect": { "x": 224, "y": 186, "width": 196, "height": 392 }', '"rect": { "x": 125, "y": 126, "width": 196, "height": 392 }'),
        @('"rect": { "x": 994, "y": 188, "width": 196, "height": 392 }', '"rect": { "x": 1117, "y": 126, "width": 196, "height": 392 }'),
        @('"rect": { "x": 460, "y": 603, "width": 98, "height": 98 }', '"rect": { "x": 849, "y": 186, "width": 98, "height": 98 }'),
        @('"rect": { "x": 857, "y": 603, "width": 98, "height": 98}', '"rect": { "x": 983, "y": 186, "width": 98, "height": 98}'),
        @('"rect": { "x": 606, "y": 601, "width": 196, "height": 98 }', '"rect": { "x": 613, "y": 416, "width": 196, "height": 98 }'),
        @('"rect": { "x": 994, "y": 601, "width": 196, "height": 196 }', '"rect": { "x": 864, "y": 320, "width": 196, "height": 196 }'),
        @('"rect": { "x": 224, "y": 603, "width": 196, "height": 196 }', '"rect": { "x": 370, "y": 321, "width": 196, "height": 196 }'),
        @('"rect": { "x": 452, "y": 750 }', '"rect": { "x": 467, "y": 1345 }'),
        @('"rect": { "x": 605, "y": 1729, "width": 257, "height": 48 }', '"rect": { "x": 141, "y": 1749, "width": 257, "height": 48 }'),
        @('"rect": { "x": 551, "y": 1729, "width": 317, "height": 44 }', '"rect": { "x": 87, "y": 1749, "width": 317, "height": 44 }')
    )

    foreach ($pair in $rects) {
        $text = Replace-AnyIfNeeded $text @($pair[0], $pair[1]) $pair[1] $File
    }

    Write-Text $File $text
}

function Patch-ControllerExpansionLayout {
    param([string]$File)

    $text = Read-Text $File
    $text = Replace-AnyIfNeeded $text @('"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Edit"', '"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Expanded"') '"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Expanded"' $File

    $rects = @(
        @('"rect": { "x": 215, "y": 134 }', '"rect": { "x": 116, "y": 74 }'),
        @('"rect": { "x": 985, "y": 134 }', '"rect": { "x": 1108, "y": 72 }'),
        @('"rect": { "x": 227, "y": 131, "width": 84, "height": 48 }', '"rect": { "x": 128, "y": 71, "width": 84, "height": 48 }'),
        @('"rect": { "x": 332, "y": 131, "width": 84, "height": 48 }', '"rect": { "x": 233, "y": 71, "width": 84, "height": 48 }'),
        @('"rect": { "x": 998, "y": 131, "width": 84, "height": 48 }', '"rect": { "x": 1121, "y": 69, "width": 84, "height": 48 }'),
        @('"rect": { "x": 1104, "y": 131, "width": 84, "height": 48 }', '"rect": { "x": 1227, "y": 69, "width": 84, "height": 48 }'),
        @('"rect": { "x": 220, "y": 69, "width": 197, "height": 48 }', '"rect": { "x": 121, "y": 9, "width": 197, "height": 48 }'),
        @('"rect": { "x": 996, "y": 69, "width": 197, "height": 48 }', '"rect": { "x": 1119, "y": 7, "width": 197, "height": 48 }')
    )

    foreach ($pair in $rects) {
        $text = Replace-AnyIfNeeded $text @($pair[0], $pair[1]) $pair[1] $File
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
    Assert-True $profile.Contains('"RightPanelRect_ExpandedInventory": { "x": -1140, "y": -856, "width": 1562, "height": 1707 }') "_profilehd.json does not use the original EasternSunLAN expanded panel rect"
    Assert-True $profile.Contains('"PanelClickCatcherRect_ExpandedInventory": { "x": 0, "y": 0, "width": 1562, "height": 1737 }') "_profilehd.json does not use the original EasternSunLAN click catcher rect"
    Assert-True $profile.Contains('"RightHingeRect_ExpandedInventory": { "x": 1076, "y": 630 }') "_profilehd.json does not use the original EasternSunLAN expanded hinge rect"

    $profileLv = Read-Text $Paths.ProfileLv
    Assert-True $profileLv.Contains('"RightPanelRect_ExpandedInventory": { "x": -1346, "y": 0, "width": 1162, "height": 1737, "scale": 1.16 }') "_profilelv.json does not use the original EasternSunLAN expanded panel rect"

    $hd = Read-Text $Paths.HdLayout
    $d2rlan = Read-Text $Paths.D2RLANExpandedTemplate

    foreach ($pair in @(@("HD layout", $hd), @("D2RLAN expanded template", $d2rlan))) {
        $name = $pair[0]
        $text = $pair[1]
        Assert-True $text.Contains('"rect": "$RightPanelRect_ExpandedInventory"') "$name does not use expanded inventory panel rect"
        Assert-True $text.Contains('"rect": "$PanelClickCatcherRect_ExpandedInventory"') "$name does not use the original EasternSunLAN click catcher rect"
        Assert-True $text.Contains('"filename": "PANEL\\Inventory\\Background_Expanded2"') "$name does not use the original EasternSunLAN expanded inventory background"
        Assert-True $text.Contains('"rect": { "x": 93, "y": 819 }') "$name does not use the original EasternSunLAN 13x8 inventory grid position"
        Assert-True $text.Contains('"cellCount": { "x": 13, "y": 8 }') "$name is not 13x8"
        Assert-True $text.Contains('"rect": { "x": 482, "y": 105, "width": 196, "height": 196 }') "$name does not use the original head slot position"
        Assert-True $text.Contains('"rect": { "x": 109, "y": 152, "width": 196, "height": 392 }') "$name does not use the original right weapon slot position"
    }

    $hdExpansion = Read-Text $Paths.HdExpansionLayout
    $d2rlanExpansion = Read-Text $Paths.D2RLANExpansionTemplate
    Assert-True $hdExpansion.Contains('"filename": "PANEL\\Inventory\\Background_Expanded2"') "HD expansion layout does not use the original EasternSunLAN expanded background"
    Assert-True $d2rlanExpansion.Contains('"filename": "PANEL\\Inventory\\Background_Expanded2"') "D2RLAN expansion template does not use the original EasternSunLAN expanded background"
    Assert-True $hdExpansion.Contains('"rect": { "x": 99, "y": 100 }') "HD expansion layout does not use the original weapon swap tab position"
    Assert-True $d2rlanExpansion.Contains('"rect": { "x": 99, "y": 100 }') "D2RLAN expansion template does not use the original weapon swap tab position"

    $legacy = Read-Text $Paths.LegacyLayout
    $controller = Read-Text $Paths.ControllerLayout
    Assert-True $legacy.Contains('"cellCount": { "x": 13, "y": 8 }') "legacy layout is not 13x8"
    Assert-True $controller.Contains('"cellCount": { "x": 13, "y": 8 }') "controller layout is not 13x8"
    Assert-True $controller.Contains('"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Classic_Expanded"') "controller layout does not use the 13x8 classic controller background"
    Assert-True $controller.Contains('"rect": { "x": 84, "y": 549}') "controller layout does not use the official 13x8 grid position"

    $controllerExpansion = Read-Text $Paths.ControllerExpansionLayout
    Assert-True $controllerExpansion.Contains('"filename": "Controller/Panel/InventoryPanel/V2/InventoryBG_Expanded"') "controller expansion layout does not use the 13x8 expanded controller background"

    foreach ($asset in @(
        "data\hd\global\ui\panel\inventory\background_expanded2.sprite",
        "data\hd\global\ui\panel\inventory\classic_background_expanded.sprite",
        "data\hd\global\ui\panel\inventory\background_expanded.sprite",
        "data\hd\global\ui\controller\panel\inventorypanel\v2\inventorybg_classic_expanded.sprite",
        "data\hd\global\ui\controller\panel\inventorypanel\v2\inventorybg_expanded.sprite"
    )) {
        Assert-True (Test-Path (Join-Path $Paths.MpqRoot $asset)) "Missing 13x8 art asset: $asset"
    }

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

Copy-OverlayAssets $paths
Patch-InventoryTxt $paths.Inventory
Patch-ProfileHd $paths.ProfileHd
Patch-ProfileLv $paths.ProfileLv
Patch-InventoryOriginalHdArt $paths.HdLayout
Patch-InventoryOriginalHdArt $paths.D2RLANExpandedTemplate
Patch-InventoryExpansionHdArt $paths.HdExpansionLayout
Patch-InventoryExpansionHdArt $paths.D2RLANExpansionTemplate
Patch-LegacyLayout $paths.LegacyLayout
Patch-ControllerLayout $paths.ControllerLayout
Patch-ControllerExpansionLayout $paths.ControllerExpansionLayout

if (-not $SkipD2RLANSetting) {
    Patch-UserSettings $paths.UserSettings
}

Validate-13x8 $paths (-not $SkipD2RLANSetting)
Write-Step "Install complete: EasternSunLAN inventory is now 13x8"
