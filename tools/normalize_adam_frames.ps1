Add-Type -AssemblyName System.Drawing

$csPath = Join-Path $PSScriptRoot "FrameNormalizer.cs"
$csCode = [IO.File]::ReadAllText($csPath)
Add-Type -TypeDefinition $csCode -ReferencedAssemblies System.Drawing -Language CSharp

$baseDir = Split-Path $PSScriptRoot -Parent
$framesDir = Join-Path $baseDir "assets\characters\adam\frames"
$outDir = Join-Path $baseDir "assets\characters\adam\frames_normalized"

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$CANVAS_W = 848
$CANVAS_H = 1264
$BASELINE_Y = 1070

# group assignments: fileNum -> groupName
$walkFiles = @(3,4,5,6)
$runFiles = @(7,8,9,10,11,12,13,14)
$turnFiles = @(16,17,18)
$backstepFiles = @(19,20,21,22,23,24,25,26)
$airFiles = @(28,29,30,31)

# air offsets from baseline (positive = higher above baseline)
$airOffsets = @{}
$airOffsets[28] = 20
$airOffsets[29] = 80
$airOffsets[30] = 120
$airOffsets[31] = 60

function Get-ScaleForFile($num) {
    if ($walkFiles -contains $num) { return 1.94 }
    if ($runFiles -contains $num) { return 2.07 }
    if ($turnFiles -contains $num) { return 1.29 }
    if ($backstepFiles -contains $num) { return 1.90 }
    return 1.0
}

function Get-GroupForFile($num) {
    if ($walkFiles -contains $num) { return "walk" }
    if ($runFiles -contains $num) { return "run" }
    if ($turnFiles -contains $num) { return "turn" }
    if ($backstepFiles -contains $num) { return "backstep" }
    return "single"
}

$files = Get-ChildItem $framesDir -Filter "*.png" | Sort-Object { [int]($_.Name -replace '^(\d+)_.*','$1') }
$report = @()

foreach ($file in $files) {
    $num = [int]($file.Name -replace '^(\d+)_.*','$1')
    $isAir = ($airFiles -contains $num)
    $groupName = Get-GroupForFile $num
    $scale = Get-ScaleForFile $num

    $inputPath = Join-Path $framesDir $file.Name
    $outputPath = Join-Path $outDir $file.Name

    $airOffset = 0
    if ($isAir) {
        $footY = [FrameNormalizer]::GetFootY($inputPath, $scale)
        $airOffset = $footY - ($BASELINE_Y - $airOffsets[$num])
    }

    [FrameNormalizer]::NormalizeFrame($inputPath, $outputPath, $scale, $isAir, $airOffset, $CANVAS_W, $CANVAS_H, $BASELINE_Y)

    $footY = [FrameNormalizer]::GetFootY($inputPath, $scale)
    Write-Host "[$num] $($file.Name) | group=$groupName scale=$scale air=$isAir foot=$footY"

    $report += [PSCustomObject]@{ Num=$num; File=$file.Name; Group=$groupName; Scale=$scale; Air=$isAir; FootY=$footY }
}

Write-Host ""
Write-Host "=== Normalization Complete ==="
Write-Host "Total frames: $($report.Count)"
Write-Host "Output: $outDir"

# walk clipping check
Write-Host ""
Write-Host "=== Walk Clipping Check ==="
foreach ($wf in $walkFiles) {
    $f = $files | Where-Object { [int]($_.Name -replace '^(\d+)_.*','$1') -eq $wf }
    if ($f) {
        $bmp = New-Object System.Drawing.Bitmap((Join-Path $framesDir $f.Name))
        $bbox = [FrameNormalizer]::GetBoundingBox($bmp)
        $bmp.Dispose()
        if ($bbox) {
            $topM = $bbox[2]
            $botM = 500 - $bbox[3] - 1
            $status = if ($topM -lt 5 -or $botM -lt 5) { "CLIP WARNING" } else { "OK" }
            Write-Host "  $($f.Name): top=$topM bot=$botM [$status]"
        }
    }
}
