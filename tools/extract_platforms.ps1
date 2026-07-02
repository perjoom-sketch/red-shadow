<#
.SYNOPSIS
  배경 PNG에서 발판(밝은 돌) 윗면 좌표를 자동 추출하여 .tscn 충돌 좌표 생성

.USAGE
  powershell -File tools/extract_platforms.ps1 -Image "assets/bg/rooftop_climb.png"
  powershell -File tools/extract_platforms.ps1 -Image "assets/bg/rooftop_climb.png" -Threshold 200 -MinWidth 80 -Preview
#>

param(
    [string]$Image = "assets/bg/rooftop_climb.png",
    [int]$Threshold = 200,
    [int]$MinWidth = 80,
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
Write-Host "Image size: ${w}x${h}"
Write-Host "Threshold: $Threshold, MinWidth: $MinWidth"
Write-Host ""

# Convert to grayscale brightness array
$brightness = New-Object 'int[,]' $h, $w
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $c = $bmp.GetPixel($x, $y)
        $brightness[$y, $x] = [int](0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B)
    }
    if ($y % 100 -eq 0) { Write-Host "  scanning row $y / $h ..." }
}

Write-Host "Brightness scan complete. Detecting platforms..."

# Find top edges: bright pixel where pixel above is dark
$platforms = @()

for ($y = 1; $y -lt $h; $y++) {
    $inRun = $false
    $runStart = 0

    for ($x = 0; $x -le $w; $x++) {
        $isBright = ($x -lt $w) -and ($brightness[$y, $x] -ge $Threshold)
        $aboveDark = ($x -lt $w) -and ($brightness[($y - 1), $x] -lt $Threshold)
        $isTopEdge = $isBright -and $aboveDark

        if ($isTopEdge -and -not $inRun) {
            $inRun = $true
            $runStart = $x
        }
        elseif (-not $isTopEdge -and $inRun) {
            $inRun = $false
            $runWidth = $x - $runStart

            if ($runWidth -ge $MinWidth) {
                # Verify depth (at least 5 rows of brightness below)
                $mid = [int](($runStart + $x) / 2)
                $depth = 0
                for ($dy = 0; $dy -lt [Math]::Min(50, $h - $y); $dy++) {
                    if ($brightness[($y + $dy), $mid] -ge $Threshold) { $depth++ } else { break }
                }

                if ($depth -ge 5) {
                    # Expand width: check a few rows down for wider extent
                    $bestLeft = $runStart
                    $bestRight = $x
                    for ($dy = 0; $dy -lt [Math]::Min($depth, 8); $dy++) {
                        $cl = $mid
                        while ($cl -gt 0 -and $brightness[($y + $dy), ($cl - 1)] -ge $Threshold) { $cl-- }
                        $cr = $mid
                        while ($cr -lt ($w - 1) -and $brightness[($y + $dy), ($cr + 1)] -ge $Threshold) { $cr++ }
                        if (($cr - $cl) -gt ($bestRight - $bestLeft)) {
                            $bestLeft = $cl
                            $bestRight = $cr + 1
                        }
                    }

                    $platforms += @{
                        TopY = $y
                        Left = $bestLeft
                        Right = $bestRight
                        Width = $bestRight - $bestLeft
                        Depth = $depth
                    }
                }
            }
        }
    }
}

Write-Host "Raw detections: $($platforms.Count)"

# Merge nearby platforms (within 15px vertical, overlapping horizontal)
$used = @($false) * $platforms.Count
$merged = @()

for ($i = 0; $i -lt $platforms.Count; $i++) {
    if ($used[$i]) { continue }
    $used[$i] = $true
    $group = @($platforms[$i])

    for ($j = $i + 1; $j -lt $platforms.Count; $j++) {
        if ($used[$j]) { continue }
        $p = $platforms[$i]
        $q = $platforms[$j]

        if ([Math]::Abs($q.TopY - $p.TopY) -lt 15) {
            $overlap = [Math]::Min($p.Right, $q.Right) - [Math]::Max($p.Left, $q.Left)
            if ($overlap -gt -30) {
                $group += $q
                $used[$j] = $true
            }
        }
    }

    $merged += @{
        TopY = ($group | Measure-Object -Property TopY -Minimum).Minimum
        Left = ($group | Measure-Object -Property Left -Minimum).Minimum
        Right = ($group | Measure-Object -Property Right -Maximum).Maximum
        Width = ($group | Measure-Object -Property Right -Maximum).Maximum - ($group | Measure-Object -Property Left -Minimum).Minimum
        Depth = ($group | Measure-Object -Property Depth -Maximum).Maximum
    }
}

# Filter by MinWidth and sort
$final = $merged | Where-Object { $_.Width -ge $MinWidth } | Sort-Object TopY

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
    Write-Host ("{0,-4} {1,-10} {2,-10} {3,-8} {4,-8}" -f $idx, $cx, $cy, $pw, $p.TopY)
    $results += @{ CX = $cx; CY = $cy; Width = $pw; TopY = $p.TopY }
    $idx++
}

# .tscn snippet
Write-Host ""
Write-Host "# ===== .tscn SNIPPET ====="
Write-Host ""

for ($i = 0; $i -lt $results.Count; $i++) {
    $r = $results[$i]
    Write-Host "[sub_resource type=`"RectangleShape2D`" id=`"plat_$i`"]"
    Write-Host "size = Vector2($($r.Width), $ShapeHeight)"
    Write-Host ""
}

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
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 2)
    foreach ($i in 0..($results.Count - 1)) {
        $r = $results[$i]
        $top = $r.CY - [int]($ShapeHeight / 2)
        $left = $r.CX - [int]($r.Width / 2)
        $g.DrawRectangle($pen, $left, $top, $r.Width, $ShapeHeight)
    }
    $pen.Dispose()
    $g.Dispose()
    $outPath = [System.IO.Path]::ChangeExtension($fullPath, ".preview.png")
    $bmp.Save($outPath)
    Write-Host ""
    Write-Host "Preview saved: $outPath"
}

$bmp.Dispose()
Write-Host ""
Write-Host "Done."
