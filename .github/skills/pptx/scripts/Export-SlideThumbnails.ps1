<#
.SYNOPSIS
    Exports slide thumbnails and creates a labeled grid image.

.DESCRIPTION
    Opens a .pptx or .potx file via COM automation, exports each slide as a JPEG,
    then composites them into a labeled grid image using System.Drawing.
    Labels show slide index and layout name. Hidden slides are dimmed.

.PARAMETER Path
    Path to the .pptx or .potx file.

.PARAMETER OutputDir
    Directory to write thumbnails and grid image. Created if it doesn't exist.
    Defaults to a "thumbs" subdirectory next to the input file.

.PARAMETER Columns
    Number of columns in the grid. Default: 3.

.PARAMETER ThumbnailWidth
    Width of each thumbnail in pixels. Default: 400.

.EXAMPLE
    .\Export-SlideThumbnails.ps1 -Path "output/My-Deck/My-Deck.pptx"
    # Thumbnails go to output/My-Deck/thumbs/

.EXAMPLE
    .\Export-SlideThumbnails.ps1 -Path "presentation.pptx" -OutputDir "custom/dir"

.EXAMPLE
    .\Export-SlideThumbnails.ps1 -Path "template.potx" -OutputDir "output/thumbs" -Columns 4
#>
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [string]$OutputDir,

    [int]$Columns = 3,

    [int]$ThumbnailWidth = 400
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$resolvedPath = Resolve-Path $Path
if (-not (Test-Path $resolvedPath)) {
    Write-Error "File not found: $resolvedPath"
    return
}

$ext = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
if ($ext -notin '.pptx', '.potx') {
    Write-Error "Unsupported file type: $ext. Use .pptx or .potx."
    return
}

if (-not $OutputDir) {
    $inputDir = Split-Path (Resolve-Path $Path) -Parent
    $OutputDir = Join-Path $inputDir 'thumbs'
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = Resolve-Path $OutputDir

$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$app = $null
$pres = $null

try {
    $app = New-Object -ComObject PowerPoint.Application
    $app.Visible = [int]-1  # Required for slide Export to work

    # MsoTriState: msoTrue = -1, msoFalse = 0
    # WithWindow must be msoTrue for Export to function
    $pres = $app.Presentations.Open($resolvedPath.Path, [int]-1, [int]0, [int]-1)

    $slideCount = $pres.Slides.Count
    if ($slideCount -eq 0) {
        Write-Output "Presentation has no slides."
        return
    }

    # Calculate thumbnail height from slide aspect ratio
    $aspectRatio = $pres.PageSetup.SlideHeight / $pres.PageSetup.SlideWidth
    $thumbHeight = [int]($ThumbnailWidth * $aspectRatio)

    $slideImages = @()

    # Export each slide
    foreach ($slide in $pres.Slides) {
        $idx = $slide.SlideIndex
        $layoutName = try { $slide.CustomLayout.Name } catch { "unknown" }
        $hidden = $slide.SlideShowTransition.Hidden -eq -1

        $jpgPath = Join-Path $OutputDir "slide_$idx.jpg"
        $slide.Export($jpgPath, "JPG", $ThumbnailWidth, $thumbHeight)

        $slideImages += @{
            Index      = $idx
            Path       = $jpgPath
            LayoutName = $layoutName
            Hidden     = $hidden
        }
        Write-Output "Exported slide $idx ($layoutName)$(if ($hidden) {' [HIDDEN]'})"
    }

    # Build grid image
    $padding = 20
    $labelHeight = 30
    $cellWidth = $ThumbnailWidth + $padding
    $cellHeight = $thumbHeight + $labelHeight + $padding

    $rows = [math]::Ceiling($slideCount / $Columns)
    $gridWidth = ($Columns * $cellWidth) + $padding
    $gridHeight = ($rows * $cellHeight) + $padding

    $gridBitmap = New-Object System.Drawing.Bitmap($gridWidth, $gridHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($gridBitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.Clear([System.Drawing.Color]::White)

    $font = New-Object System.Drawing.Font("Segoe UI", 10)
    $brush = [System.Drawing.Brushes]::Black
    $dimBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(128, 255, 255, 255))
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::LightGray, 1)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center

    foreach ($slideInfo in $slideImages) {
        $i = $slideInfo.Index - 1
        $col = $i % $Columns
        $row = [math]::Floor($i / $Columns)

        $x = $padding + ($col * $cellWidth)
        $y = $padding + ($row * $cellHeight)

        # Draw label
        $label = "Slide $($slideInfo.Index): $($slideInfo.LayoutName)"
        if ($slideInfo.Hidden) { $label += " [HIDDEN]" }
        $labelRect = New-Object System.Drawing.RectangleF($x, $y, $ThumbnailWidth, $labelHeight)
        $graphics.DrawString($label, $font, $brush, $labelRect, $format)

        # Draw thumbnail
        $img = [System.Drawing.Image]::FromFile($slideInfo.Path)
        $graphics.DrawImage($img, $x, $y + $labelHeight, $ThumbnailWidth, $thumbHeight)
        $graphics.DrawRectangle($borderPen, $x, $y + $labelHeight, $ThumbnailWidth, $thumbHeight)

        # Dim hidden slides
        if ($slideInfo.Hidden) {
            $graphics.FillRectangle($dimBrush, $x, $y + $labelHeight, $ThumbnailWidth, $thumbHeight)
        }

        $img.Dispose()
    }

    $gridPath = Join-Path $OutputDir "thumbnails.jpg"
    $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq 'image/jpeg' }
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, [long]95
    )
    $gridBitmap.Save($gridPath, $jpegCodec, $encoderParams)

    Write-Output ""
    Write-Output "Grid saved: $gridPath"
    Write-Output "Individual slides: $OutputDir\slide_*.jpg"

    # Cleanup drawing objects
    $font.Dispose()
    $dimBrush.Dispose()
    $borderPen.Dispose()
    $format.Dispose()
    $graphics.Dispose()
    $gridBitmap.Dispose()
    $encoderParams.Dispose()
}
catch {
    Write-Error "Failed to export thumbnails: $_"
}
finally {
    if ($pres) {
        $pres.Close()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
    }
    if ($app) {
        $app.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    # Kill any PowerPoint process we started (Quit doesn't always close it)
    Get-Process POWERPNT -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -notin $existingPPT } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
