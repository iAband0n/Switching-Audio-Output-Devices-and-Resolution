Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pngPath = Join-Path $scriptDir '1545.png'
$outputIcon = Join-Path $scriptDir 'AppIcon.ico'

if (-not (Test-Path $pngPath)) {
    throw "PNG source was not found: $pngPath"
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeMethods {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
"@

$bitmap = [System.Drawing.Bitmap]::FromFile($pngPath)
try {
    $iconBitmap = New-Object System.Drawing.Bitmap 256, 256
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($bitmap, 0, 0, 256, 256)
        }
        finally {
            $graphics.Dispose()
        }

        $hIcon = $iconBitmap.GetHicon()
        try {
            $icon = [System.Drawing.Icon]::FromHandle($hIcon)
            $stream = [System.IO.File]::Create($outputIcon)
            try {
                $icon.Save($stream)
            }
            finally {
                $stream.Dispose()
                $icon.Dispose()
            }
        }
        finally {
            [NativeMethods]::DestroyIcon($hIcon) | Out-Null
        }
    }
    finally {
        $iconBitmap.Dispose()
    }
}
finally {
    $bitmap.Dispose()
}

Write-Host "Created icon: $outputIcon"
