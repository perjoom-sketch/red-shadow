Add-Type -AssemblyName System.Drawing
$p = Join-Path $PSScriptRoot "..\assets\bg\rooftop_climb.png"
$i = [System.Drawing.Image]::FromFile($p)
Write-Host "Size: $($i.Width)x$($i.Height)"
$i.Dispose()
