[CmdletBinding()]
param(
    [string]$ModRoot = ""
)

$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "install.ps1") -ModRoot $ModRoot -ValidateOnly

