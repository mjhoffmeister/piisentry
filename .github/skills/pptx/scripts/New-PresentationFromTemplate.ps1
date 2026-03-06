<#
.SYNOPSIS
    Creates a new PowerPoint presentation from a template.

.DESCRIPTION
    Opens a .potx or .pptx template via COM automation and creates a new presentation.
    For .potx files, PowerPoint natively creates a new presentation based on the template.
    For .pptx files, opens and saves as a new file.

    Optionally manipulates slide structure: keep only specific slides, duplicate slides,
    or reorder them via a JSON slide spec.

.PARAMETER TemplatePath
    Path to the template file (.potx or .pptx).

.PARAMETER OutputPath
    Path for the output .pptx file.

.PARAMETER SlideSpec
    Optional JSON string specifying slide operations. Format:
    [
        { "source": 1 },                          // Keep slide 1
        { "source": 2, "duplicate": 3 },           // Duplicate slide 2 three times
        { "source": 3 }                            // Keep slide 3
    ]
    Slides not listed are deleted. Order determines final slide order.
    If omitted, all slides are kept as-is.

.EXAMPLE
    .\New-PresentationFromTemplate.ps1 -TemplatePath "template.potx" -OutputPath "output/My-Deck/My-Deck.pptx"

.EXAMPLE
    $spec = '[{"source":1},{"source":3,"duplicate":2},{"source":5}]'
    .\New-PresentationFromTemplate.ps1 -TemplatePath "deck.pptx" -OutputPath "new.pptx" -SlideSpec $spec
#>
param(
    [Parameter(Mandatory)]
    [string]$TemplatePath,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string]$SlideSpec
)

$ErrorActionPreference = 'Stop'

# If the path doesn't exist as-is, check the default templates directory
if (-not (Test-Path $TemplatePath)) {
    $skillRoot = Split-Path $PSScriptRoot
    $defaultDir = Join-Path $skillRoot 'templates'
    $candidate = Join-Path $defaultDir $TemplatePath
    if (Test-Path $candidate) {
        $TemplatePath = $candidate
    }
}

$resolvedTemplate = Resolve-Path $TemplatePath
if (-not (Test-Path $resolvedTemplate)) {
    Write-Error "Template not found: $resolvedTemplate"
    return
}

$ext = [System.IO.Path]::GetExtension($resolvedTemplate).ToLower()
if ($ext -notin '.pptx', '.potx') {
    Write-Error "Unsupported file type: $ext. Use .pptx or .potx."
    return
}

# Ensure output directory exists
$outDir = Split-Path $OutputPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Resolve to absolute path (OutputPath may not exist yet)
$absOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path (Get-Location) $OutputPath
}

$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$app = $null
$pres = $null

try {
    $app = New-Object -ComObject PowerPoint.Application
    $app.Visible = [int]-1  # Required for Duplicate/MoveTo operations

    # MsoTriState: msoTrue = -1, msoFalse = 0

    if ($ext -eq '.potx') {
        # Opening a .potx creates a new presentation based on the template
        $pres = $app.Presentations.Open($resolvedTemplate.Path, [int]0, [int]0, [int]-1)
    }
    else {
        # For .pptx, open non-read-only so we can Duplicate/Delete slides, then SaveAs
        $pres = $app.Presentations.Open($resolvedTemplate.Path, [int]0, [int]0, [int]-1)
    }

    Write-Output "Opened template: $resolvedTemplate ($($pres.Slides.Count) slides)"

    # Apply slide spec if provided
    if ($SlideSpec) {
        $spec = $SlideSpec | ConvertFrom-Json
        $originalCount = $pres.Slides.Count

        # Strategy: duplicate source slides to the end in spec order, then delete originals.
        # This avoids index-shift headaches during delete/reorder.

        foreach ($entry in $spec) {
            $srcIdx = [int]$entry.source
            if ($srcIdx -lt 1 -or $srcIdx -gt $originalCount) {
                Write-Warning "SlideSpec references slide $srcIdx but template only has $originalCount slides. Skipping."
                continue
            }
            $copies = if ($entry.duplicate) { [int]$entry.duplicate } else { 1 }
            for ($c = 0; $c -lt $copies; $c++) {
                # Duplicate source slide — puts copy right after the source
                $dup = $pres.Slides.Item($srcIdx).Duplicate()
                # Move the duplicate to the end
                $dup.MoveTo([int]$pres.Slides.Count)
            }
        }

        # Delete the original N slides (they are still at positions 1..N)
        for ($i = [int]$originalCount; $i -ge 1; $i--) {
            $pres.Slides.Item([int]$i).Delete()
        }

        Write-Output "Applied slide spec: $($pres.Slides.Count) slides in output"
    }

    # Remove inherited slide-sorter metadata sections from the template
    $sp = $pres.SectionProperties
    if ($sp.Count -gt 0) {
        Write-Output "Removing $($sp.Count) inherited template section(s)..."
        for ($secIdx = $sp.Count; $secIdx -ge 1; $secIdx--) {
            $sp.Delete($secIdx, $false)  # $false = keep slides
        }
    }

    # ppSaveAsOpenXMLPresentation = 24
    $pres.SaveAs($absOutput, 24)
    Write-Output "Saved: $absOutput"

    # Emit shape info for each slide so the caller can immediately write edit code
    Write-Output ""
    Write-Output "=== Output Slide Shapes ==="
    for ($si = 1; $si -le $pres.Slides.Count; $si++) {
        $slide = $pres.Slides.Item($si)
        $layoutName = try { $slide.CustomLayout.Name } catch { "(unknown)" }
        Write-Output "Slide ${si}: Layout=`"$layoutName`""
        foreach ($shape in $slide.Shapes) {
            $shapeName = $shape.Name
            $hasText = $shape.HasTextFrame
            $detail = "  Shape: `"$shapeName`" Type=$($shape.Type)"
            if ($hasText) {
                $text = $shape.TextFrame.TextRange.Text
                if ($text.Length -gt 80) { $text = $text.Substring(0, 80) + "..." }
                $text = $text -replace "`r`n", " " -replace "`n", " "
                $detail += " Text=`"$text`""
            }
            $phType = try { $shape.PlaceholderFormat.Type } catch { $null }
            if ($null -ne $phType) { $detail += " Placeholder=$phType" }
            Write-Output $detail
        }
        Write-Output ""
    }
}
catch {
    Write-Error "Failed to create presentation: $_"
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
