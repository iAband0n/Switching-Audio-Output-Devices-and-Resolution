$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptDir 'DeviceSwitch.ahk'
$distDir = Join-Path $scriptDir 'dist'
$output = Join-Path $distDir 'DeviceSwitch.exe'
$iconFile = Join-Path $scriptDir 'icon.ico'
$iconBuilder = Join-Path $scriptDir 'export_icon.ps1'

$compilerCandidates = @(
    (Join-Path $scriptDir 'Ahk2Exe.exe'),
    'C:\Program Files\AutoHotkey\Ahk2Exe.exe',
    'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe',
    'C:\Program Files\AutoHotkey\UX\Ahk2Exe.exe',
    'C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe'
)

$baseCandidates = @(
    'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
    'C:\Program Files\AutoHotkey\v2\AutoHotkey.exe'
)

$runtimeItems = @(
    'SetDefaultAudioDevice.ps1',
    'icon.ico'
)

$runtimeDirs = @()

$compiler = $compilerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $compiler) {
    throw "Ahk2Exe.exe was not found. Install AutoHotkey Compiler or place Ahk2Exe.exe in a standard AutoHotkey directory, then run this script again."
}

$baseExe = $baseCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $baseExe) {
    throw "AutoHotkey v2 base executable was not found. Install AutoHotkey v2 before compiling."
}

if (-not (Test-Path $source)) {
    throw "Source file was not found: $source"
}

if (-not (Test-Path $iconFile)) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $iconBuilder
}

New-Item -ItemType Directory -Path $distDir -Force | Out-Null
& $compiler /in $source /out $output /icon $iconFile /base $baseExe

# Ahk2Exe 有时会在进程退出后短暂延迟写出目标文件。
$outputCreated = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    if (Test-Path $output) {
        $outputCreated = $true
        break
    }
    Start-Sleep -Milliseconds 500
}

if (-not $outputCreated) {
    throw "Compile command finished, but output file was not created: $output"
}

Copy-Item -Path (Join-Path $scriptDir 'DeviceSwitch.ini') -Destination (Join-Path $distDir 'DeviceSwitch.ini') -Force -ErrorAction SilentlyContinue

foreach ($item in $runtimeItems) {
    $src = Join-Path $scriptDir $item
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $distDir $item) -Force
    }
}

foreach ($dir in $runtimeDirs) {
    $srcDir = Join-Path $scriptDir $dir
    if (Test-Path $srcDir) {
        Copy-Item -Path $srcDir -Destination (Join-Path $distDir $dir) -Recurse -Force
    }
}

Write-Host "Built: $output"

