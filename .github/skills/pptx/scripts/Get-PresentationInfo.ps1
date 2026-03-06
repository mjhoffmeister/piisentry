<#
.SYNOPSIS
    Analyzes a PowerPoint file and reports its structure.

.DESCRIPTION
    Opens a .pptx or .potx file via COM automation and outputs:
    - Slide dimensions
    - Slide count
    - Slide master and layout information
    - Per-slide details: index, layout name, title text, shape inventory, hidden status

.PARAMETER Path
    Path to the .pptx or .potx file to analyze.

.PARAMETER LayoutsOnly
    Output only a compact list of slide indices and layout names (one per line,
    deduplicated to first occurrence). Useful for quickly surveying a large template.

.PARAMETER SlideRange
    Comma-separated slide numbers and ranges to include in the output.
    Example: "25,41-45,61" shows only those slides' shape details.
    Ignored when -LayoutsOnly is set.

.EXAMPLE
    .\Get-PresentationInfo.ps1 -Path "template.potx"

.EXAMPLE
    .\Get-PresentationInfo.ps1 -Path "template.potx" -LayoutsOnly

.EXAMPLE
    .\Get-PresentationInfo.ps1 -Path "template.potx" -SlideRange "25,41-45,61"
#>
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$LayoutsOnly,

    [string]$SlideRange
)

$ErrorActionPreference = 'Stop'

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

$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$app = $null
$pres = $null

try {
    $app = New-Object -ComObject PowerPoint.Application

    # Open read-only, no window: Open(FileName, ReadOnly, Untitled, WithWindow)
    # MsoTriState: msoTrue = -1, msoFalse = 0
    $pres = $app.Presentations.Open($resolvedPath.Path, [int]-1, [int]0, [int]0)

    $slideWidth = [math]::Round($pres.PageSetup.SlideWidth / 72, 2)
    $slideHeight = [math]::Round($pres.PageSetup.SlideHeight / 72, 2)

    Write-Output "=== Presentation Info ==="
    Write-Output "File: $resolvedPath"
    Write-Output "Dimensions: ${slideWidth}`" x ${slideHeight}`" ($(
        if ($slideWidth -eq 13.33 -and $slideHeight -eq 7.5) { 'Widescreen 16:9' }
        elseif ($slideWidth -eq 10 -and $slideHeight -eq 7.5) { 'Standard 4:3' }
        else { 'Custom' }
    ))"
    Write-Output "Slide count: $($pres.Slides.Count)"
    Write-Output ""

    # Slide masters and layouts (use Designs collection — SlideMasters.Count returns 0 in COM interop)
    if (-not $LayoutsOnly) {
        Write-Output "=== Slide Masters & Layouts ==="
        for ($di = 1; $di -le $pres.Designs.Count; $di++) {
            $design = $pres.Designs.Item($di)
            $master = $design.SlideMaster
            Write-Output "Master: $($design.Name)"
            for ($li = 1; $li -le $master.CustomLayouts.Count; $li++) {
                $layout = $master.CustomLayouts.Item($li)
                Write-Output "  Layout [$li]: $($layout.Name)"
            }
        }
        Write-Output ""
    }

    # Parse -SlideRange into a set of slide numbers
    $slideFilter = $null
    if ($SlideRange -and -not $LayoutsOnly) {
        $slideFilter = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($part in $SlideRange -split ',') {
            $part = $part.Trim()
            if ($part -match '^(\d+)-(\d+)$') {
                $rangeStart = [int]$Matches[1]
                $rangeEnd   = [int]$Matches[2]
                for ($r = $rangeStart; $r -le $rangeEnd; $r++) {
                    [void]$slideFilter.Add($r)
                }
            }
            elseif ($part -match '^\d+$') {
                [void]$slideFilter.Add([int]$part)
            }
        }
    }

    # Per-slide details
    if ($LayoutsOnly) {
        Write-Output "=== Layouts (first occurrence) ==="
        $seen = [System.Collections.Generic.HashSet[string]]::new()
        for ($si = 1; $si -le $pres.Slides.Count; $si++) {
            $slide = $pres.Slides.Item($si)
            $layoutName = try { $slide.CustomLayout.Name } catch { "(unknown)" }
            if ($seen.Add($layoutName)) {
                Write-Output "Slide ${si}: $layoutName"
            }
        }
    }
    else {
        Write-Output "=== Slides ==="
        for ($si = 1; $si -le $pres.Slides.Count; $si++) {
            if ($slideFilter -and -not $slideFilter.Contains($si)) { continue }

            $slide = $pres.Slides.Item($si)
            $layoutName = try { $slide.CustomLayout.Name } catch { "(unknown)" }
            $hidden = $slide.SlideShowTransition.Hidden -eq -1

            # Extract title text from title placeholder
            $titleText = ""
            foreach ($shape in $slide.Shapes) {
                if ($shape.HasTextFrame) {
                    $phType = try { $shape.PlaceholderFormat.Type } catch { -1 }
                    # ppPlaceholderTitle = 1, ppPlaceholderCenterTitle = 3
                    if ($phType -eq 1 -or $phType -eq 3) {
                        $titleText = $shape.TextFrame.TextRange.Text
                        break
                    }
                }
            }

            $status = if ($hidden) { " [HIDDEN]" } else { "" }
            Write-Output "Slide $($slide.SlideIndex): Layout=`"$layoutName`"$status"
            if ($titleText) {
                Write-Output "  Title: $titleText"
            }

            # Shape inventory
            foreach ($shape in $slide.Shapes) {
                $shapeType = $shape.Type
                $shapeName = $shape.Name
                $hasText = $shape.HasTextFrame

                $detail = "  Shape: `"$shapeName`" Type=$shapeType"
                if ($hasText) {
                    $text = $shape.TextFrame.TextRange.Text
                    if ($text.Length -gt 80) { $text = $text.Substring(0, 80) + "..." }
                    $text = $text -replace "`r`n", " " -replace "`n", " "
                    $detail += " Text=`"$text`""
                }

                $phType = try { $shape.PlaceholderFormat.Type } catch { $null }
                if ($null -ne $phType) {
                    $detail += " Placeholder=$phType"
                }

                Write-Output $detail
            }
            Write-Output ""
        }
    }
}
catch {
    Write-Error "Failed to analyze presentation: $_"
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
