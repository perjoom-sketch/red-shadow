<#
.SYNOPSIS
  배경 PNG에서 밝은 발판 영역을 감지하여 충돌 좌표 추출 (v2 - 행별 스캔 방식)

.USAGE
  powershell -File tools/extract_platforms_v2.ps1 -Image "assets/bg/rooftop_climb.png" -Threshold 180
#>

param(
    [string]$Image = "assets/bg/rooftop_climb.png",
    [int]$Threshold = 180,
    [int]$MinWidth = 100,
    [int]$ShapeHeight = 22,
    [switch]$Preview
)

Add-Type -AssemblyName System.Drawing

$fullPath = if ([System.IO.Path]::IsPathRooted($Image)) { $Image } else { Join-Path $PSScriptRoot "..\$Image" }
$fullPath = [System.IO.Path]::GetFullPath($fullPath)

Write-Host "Loading: $fullPath"
$bmp = New-Object System.Drawing.Bitmap($fullPath)
$w = $bmp.Width
$h = $bmp.Height
Write-Host "Image: ${w}x${h}, Threshold: $Threshold, MinWidth: $MinWidth"

# Step 1: Build brightness array
Write-Host "Scanning brightness..."
$bright = New-Object 'bool[,]' $h, $w
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $c = $bmp.GetPixel($x, $y)
        $b = [int](0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B)
        $bright[$y, $x] = ($b -ge $Threshold)
    }
    if ($y % 200 -eq 0) { Write-Host "  row $y / $h" }
}

# Step 2: For each row, find horizontal bright runs >= MinWidth
Write-Host "Finding horizontal runs..."
$allRuns = @()

for ($y = 0; $y -lt $h; $y++) {
    $inRun = $false
    $start = 0

    for ($x = 0; $x -le $w; $x++) {
        $on = ($x -lt $w) -and $bright[$y, $x]

        if ($on -and -not $inRun) {
            $inRun = $true
            $start = $x
        }
        elseif (-not $on -and $inRun) {
            $inRun = $false
            $runW = $x - $start
            if ($runW -ge $MinWidth) {
                $allRuns += @{ Y = $y; Left = $start; Right = $x; Width = $runW }
            }
        }
    }
}

Write-Host "  Total bright runs: $($allRuns.Count)"

# Step 3: Group vertically adjacent runs into platform blobs
# Sort by Y, then merge overlapping runs within 5 rows
$allRuns = $allRuns | Sort-Object { $_.Y }, { $_.Left }

$blobs = @()
$used = @($false) * $allRuns.Count

for ($i = 0; $i -lt $allRuns.Count; $i++) {
    if ($used[$i]) { continue }
    $used[$i] = $true
    $blob = @($allRuns[$i])
    $lastY = $allRuns[$i].Y

    # Expand blob downward
    for ($j = $i + 1; $j -lt $allRuns.Count; $j++) {
        if ($used[$j]) { continue }
        $r = $allRuns[$j]

        # Within 3 rows of last added row and horizontally overlapping
        if ($r.Y - $lastY -gt 3) { break }  # sorted by Y, so can break early... actually no, there might be runs at same Y. Let me just continue
        if ($r.Y - $lastY -gt 3 -and $r.Y -gt ($lastY + 3)) { continue }

        # Check horizontal overlap with any run in blob
        $blobLeft = ($blob | Measure-Object -Property Left -Minimum).Minimum
        $blobRight = ($blob | Measure-Object -Property Right -Maximum).Maximum
        $overlap = [Math]::Min($blobRight, $r.Right) - [Math]::Max($blobLeft, $r.Left)

        if ($overlap -gt 20 -and ($r.Y - $lastY) -le 3) {
            $blob += $r
            $used[$j] = $true
            $lastY = $r.Y
        }
    }

    # Only keep blobs with at least 3 rows
    $rows = ($blob | Select-Object -Property Y -Unique).Count
    if ($rows -ge 3) {
        $blobs += ,@($blob)
    }
}

Write-Host "  Blobs (after grouping): $($blobs.Count)"

# Step 4: For each blob, compute platform bounds
$platforms = @()

foreach ($blob in $blobs) {
    $topY = ($blob | Measure-Object -Property Y -Minimum).Minimum
    $left = ($blob | Measure-Object -Property Left -Minimum).Minimum
    $right = ($blob | Measure-Object -Property Right -Maximum).Maximum
    $botY = ($blob | Measure-Object -Property Y -Maximum).Maximum
    $pw = $right - $left

    if ($pw -ge $MinWidth) {
        $platforms += @{
            TopY = $topY
            Left = $left
            Right = $right
            Width = $pw
            Height = $botY - $topY + 1
        }
    }
}

# Merge platforms that are within 20px vertical and overlapping horizontal
$merged = @()
$pUsed = @($false) * $platforms.Count

for ($i = 0; $i -lt $platforms.Count; $i++) {
    if ($pUsed[$i]) { continue }
    $pUsed[$i] = $true
    $group = @($platforms[$i])

    for ($j = $i + 1; $j -lt $platforms.Count; $j++) {
        if ($pUsed[$j]) { continue }
        if ([Math]::Abs($platforms[$j].TopY - $platforms[$i].TopY) -lt 20) {
            $overlap = [Math]::Min($platforms[$i].Right, $platforms[$j].Right) - [Math]::Max($platforms[$i].Left, $platforms[$j].Left)
            if ($overlap -gt -50) {
                $group += $platforms[$j]
                $pUsed[$j] = $true
            }
        }
    }

    $merged += @{
        TopY = ($group | Measure-Object -Property TopY -Minimum).Minimum
        Left = ($group | Measure-Object -Property Left -Minimum).Minimum
        Right = ($group | Measure-Object -Property Right -Maximum).Maximum
        Width = ($group | Measure-Object -Property Right -Maximum).Maximum - ($group | Measure-Object -Property Left -Minimum).Minimum
    }
}

$final = $merged | Where-Object { $_.Width -ge $MinWidth } | Sort-Object TopY

# Output
Write-Host ""
Write-Host "=== Detected $($final.Count) platforms ==="
Write-Host ""
Write-Host ("{0,-4} {1,-10} {2,-10} {3,-8} {4,-8}" -f "#", "CenterX", "CenterY", "Width", "TopY")
Write-Host ("-" * 44)

$results = @()
$idx = 0
foreach ($p in $final) {
    $cx = [int](($p.Left + $p.Right) / 2)
    $cy = $p.TopY + [int]($ShapeHeight / 2)
    $pw = $p.Width
    $results += @{ CX = $cx; CY = $cy; Width = $pw; TopY = $p.TopY }
    Write-Host ("{0,-4} {1,-10} {2,-10} {3,-8} {4,-8}" -f $idx, $cx, $cy, $pw, $p.TopY)
    $idx++
}

# .tscn snippet
Write-Host ""
Write-Host "# ===== .tscn SNIPPET (copy-paste into Main.tscn) ====="
Write-Host ""

Write-Host "# Sub Resources:"
for ($i = 0; $i -lt $results.Count; $i++) {
    $r = $results[$i]
    Write-Host "[sub_resource type=`"RectangleShape2D`" id=`"plat_$i`"]"
    Write-Host "size = Vector2($($r.Width), $ShapeHeight)"
    Write-Host ""
}

Write-Host "# Nodes:"
for ($i = 0; $i -lt $results.Count; $i++) {
    $r = $results[$i]
    Write-Host "[node name=`"P$i`" type=`"StaticBody2D`" parent=`"LevelCollision`"]"
    Write-Host "position = Vector2($($r.CX), $($r.CY))"
    Write-Host ""
    Write-Host "[node name=`"C`" type=`"CollisionShape2D`" parent=`"LevelCollision/P$i`"]"
    Write-Host "shape = SubResource(`"plat_$i`")"
    Write-Host ""
}

# Preview
if ($Preview) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $penRed = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 2)
    $penGreen = New-Object System.Drawing.Pen([System.Drawing.Color]::Lime, 1)
    $font = New-Object System.Drawing.Font("Arial", 10)
    $brush = [System.Drawing.Brushes]::Yellow

    foreach ($i in 0..($results.Count - 1)) {
        $r = $results[$i]
        $top = $r.TopY
        $left = $r.CX - [int]($r.Width / 2)
        $g.DrawRectangle($penRed, $left, $top, $r.Width, $ShapeHeight)
        $g.DrawString("P$i", $font, $brush, ($left + 4), ($top - 14))
    }
    $penRed.Dispose()
    $penGreen.Dispose()
    $font.Dispose()
    $g.Dispose()
    $outPath = [System.IO.Path]::ChangeExtension($fullPath, ".preview.png")
    $bmp.Save($outPath)
    Write-Host "`nPreview saved: $outPath"
}

$bmp.Dispose()
Write-Host "`nDone."
