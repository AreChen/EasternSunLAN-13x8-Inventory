[CmdletBinding()]
param(
    [string]$InstallScript = (Join-Path $PSScriptRoot "install.ps1")
)

$ErrorActionPreference = "Stop"

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )

    if (-not $Text.Contains($Needle)) {
        throw $Message
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )

    if ($Text.Contains($Needle)) {
        throw $Message
    }
}

$text = [System.IO.File]::ReadAllText((Resolve-Path -Path $InstallScript -ErrorAction Stop).Path)

Assert-Contains $text '"RightPanelRect_ExpandedInventory" ''{ "x": -1434, "y": -856, "width": 1856, "height": 1707 }''' "HD parent panel must shift left by 294px so the 13x8 frame is visible on 16:9."
Assert-Contains $text '"PanelClickCatcherRect_ExpandedInventory" ''{ "x": 0, "y": 0, "width": 1456, "height": 1737 }''' "HD click catcher must cover the 13-column visual grid."
Assert-Contains $text '"RightHingeRect_ExpandedInventory" ''{ "x": 1370, "y": 630 }''' "HD hinge must move right inside the expanded frame."
Assert-Contains $text '''"rect": { "x": 1374, "y": 1 }''' "HD close button must move right inside the expanded frame."
Assert-Contains $text '''"rect": { "x": 93, "y": 819 }''' "HD inventory grid must keep the EasternSunLAN local grid origin."
Assert-Contains $text '''"cellCount": { "x": 13, "y": 8 }''' "Inventory grid must be 13x8."
Assert-Contains $text '''"rect": { "x": 630, "y": 105, "width": 196, "height": 196 }''' "Head slot must be centered in the expanded HD panel."
Assert-Contains $text '''"rect": { "x": 630, "y": 348, "width": 196, "height": 294 }''' "Torso slot must be centered in the expanded HD panel."
Assert-Contains $text '''"rect": { "x": 630, "y": 689, "width": 196, "height": 98 }''' "Belt slot must be centered in the expanded HD panel."
Assert-Contains $text "Using manual 13x8 HD inventory background" "Installer must keep the hand-authored 13x8 background from the overlay."
Assert-NotContains $text 'New-ExpandedOriginalBackgroundSprites $paths' "Installer must not regenerate and overwrite the hand-authored 13x8 background."
Assert-Contains $text "Patch-AutoStockerDll" "Installer must patch AutoStocker DLL coordinates for the visible left-expanded layout."
Assert-Contains $text "[double]1434" "AutoStocker DLL patch must target the left-expanded panel offset."

Write-Host "visible autostocker inventory layout constants ok"
