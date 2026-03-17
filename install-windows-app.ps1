<#
.SYNOPSIS
    Build and install TreeLauncher for Windows.

.DESCRIPTION
    Builds the Flutter Windows application and copies the output to a specified
    installation directory (default: %LOCALAPPDATA%\Programs\TreeLauncher).

.PARAMETER InstallDir
    Target installation directory. Defaults to "$env:LOCALAPPDATA\Programs\TreeLauncher".

.EXAMPLE
    .\install-windows-app.ps1
    .\install-windows-app.ps1 -InstallDir "C:\MyApps\TreeLauncher"
#>

param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\TreeLauncher"
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot  = $scriptDir

$sourceDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'

Write-Host "Building TreeLauncher for Windows..."
Push-Location $repoRoot
try {
    flutter build windows @args
} finally {
    Pop-Location
}

if (-not (Test-Path $sourceDir)) {
    Write-Error "Build succeeded, but output was not found at $sourceDir"
    exit 1
}

Write-Host "Installing to $InstallDir..."

if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
}

Copy-Item -Recurse -Force $sourceDir $InstallDir

Write-Host "Installed TreeLauncher to $InstallDir"
