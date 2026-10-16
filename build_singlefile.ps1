$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildScript = Join-Path $scriptDir 'build.ps1'
$distDir = Join-Path $scriptDir 'dist'
$stageDir = Join-Path $scriptDir '.singlefile_build'
$payloadZip = Join-Path $stageDir 'payload.zip'
$launcherSource = Join-Path $scriptDir 'SingleFileLauncher.cs'
$iconFile = Join-Path $scriptDir 'icon.ico'
$outputExe = Join-Path $distDir 'Switch UR Device.exe'
$cscCandidates = @(
    'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe',
    'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'
)

$csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) {
    throw "csc.exe was not found."
}

if (Test-Path $distDir) {
    # 清空旧产物，避免旧文件被意外打入 payload，最终 dist 中只保留单个 EXE。
    Get-ChildItem -Path $distDir -Force | Remove-Item -Recurse -Force
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $buildScript

if (-not (Test-Path $distDir)) {
    throw "dist directory was not found: $distDir"
}

if (-not (Test-Path $launcherSource)) {
    throw "Launcher source was not found: $launcherSource"
}

if (-not (Test-Path $iconFile)) {
    throw "Icon file was not found: $iconFile"
}

if (Test-Path $stageDir) {
    Remove-Item -Path $stageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stageDir | Out-Null

$itemsToPack = Get-ChildItem -Path $distDir
if (-not $itemsToPack) {
    throw "No files were found in dist to package."
}

Compress-Archive -Path ($itemsToPack | ForEach-Object { $_.FullName }) -DestinationPath $payloadZip -Force

if (Test-Path $outputExe) {
    Remove-Item -Path $outputExe -Force
}

$compilerArgs = @(
    '/nologo'
    '/target:winexe'
    "/out:$outputExe"
    "/win32icon:$iconFile"
    "/resource:$payloadZip,payload.zip"
    '/reference:System.Windows.Forms.dll'
    '/reference:System.IO.Compression.dll'
    '/reference:System.IO.Compression.FileSystem.dll'
    $launcherSource
)

& $csc $compilerArgs

if (-not (Test-Path $outputExe)) {
    throw "Single-file package was not created: $outputExe"
}

$filesToRemove = Get-ChildItem -Path $distDir | Where-Object { $_.FullName -ne $outputExe }
foreach ($item in $filesToRemove) {
    $removed = $false
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        try {
            Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
            $removed = $true
            break
        } catch {
            Start-Sleep -Milliseconds 300
        }
    }
    if (-not $removed) {
        throw "Failed to remove intermediate file: $($item.FullName)"
    }
}

if (Test-Path $stageDir) {
    Remove-Item -Path $stageDir -Recurse -Force
}

Write-Host "Built single-file package: $outputExe"
