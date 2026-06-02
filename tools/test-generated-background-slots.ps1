[CmdletBinding()]
param(
    [string]$ModRoot = "H:\D2\D2R\Mods\EasternSunLAN",
    [string]$RepoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-SpriteInfo {
    param([string]$Path)

    Assert-True (Test-Path $Path) "Missing sprite: $Path"
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return @{
        Path = $Path
        Bytes = $bytes
        Width = [BitConverter]::ToUInt16($bytes, 6)
        Width2 = [BitConverter]::ToUInt16($bytes, 8)
        Height = [BitConverter]::ToUInt16($bytes, 12)
    }
}

function Assert-SpriteMatchesOverlay {
    param(
        [string]$RelativePath,
        [int]$ExpectedWidth,
        [int]$ExpectedHeight
    )

    $overlay = Get-SpriteInfo (Join-Path $RepoRoot "overlay\EasternSunLAN.mpq\$RelativePath")
    $target = Get-SpriteInfo (Join-Path (Join-Path $ModRoot "EasternSunLAN.mpq") $RelativePath)

    foreach ($sprite in @($overlay, $target)) {
        Assert-True ($sprite.Width -eq $ExpectedWidth) "$($sprite.Path) width is $($sprite.Width), expected $ExpectedWidth"
        Assert-True ($sprite.Width2 -eq $ExpectedWidth) "$($sprite.Path) second width is $($sprite.Width2), expected $ExpectedWidth"
        Assert-True ($sprite.Height -eq $ExpectedHeight) "$($sprite.Path) height is $($sprite.Height), expected $ExpectedHeight"
        Assert-True ($sprite.Bytes.Length -eq (40 + ($ExpectedWidth * $ExpectedHeight * 4))) "$($sprite.Path) has unexpected sprite length"
    }

    Assert-True ($overlay.Bytes.Length -eq $target.Bytes.Length) "$RelativePath target length differs from overlay"
    for ($i = 0; $i -lt $overlay.Bytes.Length; $i++) {
        if ($overlay.Bytes[$i] -ne $target.Bytes[$i]) {
            throw "$RelativePath differs from the hand-authored overlay sprite at byte $i"
        }
    }
}

Assert-SpriteMatchesOverlay "data\hd\global\ui\panel\inventory\background_expanded2_13x8.sprite" 1456 1737
Assert-SpriteMatchesOverlay "data\hd\global\ui\panel\inventory\background_expanded2_13x8.lowend.sprite" 728 869

Write-Host "manual background sprite overlay matches target"
