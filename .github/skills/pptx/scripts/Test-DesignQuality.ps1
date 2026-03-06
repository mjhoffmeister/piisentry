<#
.SYNOPSIS
    Audits a PowerPoint presentation for design quality issues.

.DESCRIPTION
    Opens a .pptx file via COM automation and checks for design quality:
    - Empty image placeholders (layout chosen but no image provided)
    - Consecutive slides with the same layout (3+ in a row)
    - Content density (too many bullets or words per bullet)
    - Empty placeholder text (template leftovers)
    - Missing speaker notes on content slides

    Outputs a per-slide report of issues found with severity (Error/Warning)
    and remediation guidance.

.PARAMETER Path
    Path to the .pptx file to audit.

.EXAMPLE
    .\Test-DesignQuality.ps1 -Path "output/My-Deck/My-Deck.pptx"
#>
param(
    [Parameter(Mandatory)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

$resolvedPath = Resolve-Path $Path
if (-not (Test-Path $resolvedPath)) {
    Write-Error "File not found: $resolvedPath"
    return
}

$ext = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
if ($ext -ne '.pptx') {
    Write-Error "Unsupported file type: $ext. Use .pptx files only."
    return
}

# Layouts that are excluded from speaker notes check
$skipNotesLayouts = @('Section', 'Thank you', 'Thank you ', 'Splash page', 'Blank', 'Blank entirely', 'Demo')

# --- COM Setup ---

$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$app = $null
$pres = $null
$issues = @()

try {
    $app = New-Object -ComObject PowerPoint.Application
    # Open read-only
    $pres = $app.Presentations.Open($resolvedPath.Path, [int]-1, [int]0, [int]0)

    Write-Output "=== Design Quality Audit ==="
    Write-Output "File: $resolvedPath"
    Write-Output "Slides: $($pres.Slides.Count)"
    Write-Output ""

    # Collect layout names for consecutive-layout check
    $layoutNames = @()
    for ($si = 1; $si -le $pres.Slides.Count; $si++) {
        $layoutNames += $pres.Slides.Item($si).Layout
        # Store custom layout name
    }

    # Build layout name list using CustomLayout.Name
    $layoutNameStrings = @()
    for ($si = 1; $si -le $pres.Slides.Count; $si++) {
        try {
            $layoutNameStrings += $pres.Slides.Item($si).CustomLayout.Name
        } catch {
            $layoutNameStrings += "Unknown"
        }
    }

    for ($si = 1; $si -le $pres.Slides.Count; $si++) {
        $slide = $pres.Slides.Item($si)
        $slideIssues = @()
        $layoutName = $layoutNameStrings[$si - 1]

        # --- Check 1: Empty image placeholders ---
        foreach ($shape in $slide.Shapes) {
            $shapeName = $shape.Name
            $shapeType = $shape.Type

            # msoPlaceholder = 14
            if ($shapeType -eq 14) {
                $isPicturePlaceholder = $false
                try {
                    # ppPlaceholderPicture = 18
                    $isPicturePlaceholder = ($shape.PlaceholderFormat.Type -eq 18)
                } catch { }

                if ($isPicturePlaceholder) {
                    # Check if the placeholder has a picture fill
                    $hasPicture = $false
                    try {
                        # ppFillPicture = 6 (msoFillPicture)
                        $hasPicture = ($shape.Fill.Type -eq 6)
                    } catch { }

                    if (-not $hasPicture) {
                        $slideIssues += [PSCustomObject]@{
                            Severity = 'Error'
                            Check    = 'Empty Image'
                            Detail   = "Picture placeholder '$shapeName' has no image. Add an image or switch to a text-only layout."
                        }
                    }
                }
            }
        }

        # --- Check 2: Consecutive same-layout (check on first slide of a run) ---
        if ($si -ge 3) {
            $current = $layoutNameStrings[$si - 1]
            $prev1 = $layoutNameStrings[$si - 2]
            $prev2 = $layoutNameStrings[$si - 3]
            if ($current -eq $prev1 -and $current -eq $prev2) {
                # Only report on the 3rd consecutive slide to avoid duplicate warnings
                $alreadyReported = ($si -ge 4 -and $layoutNameStrings[$si - 4] -eq $current)
                if (-not $alreadyReported) {
                    $slideIssues += [PSCustomObject]@{
                        Severity = 'Warning'
                        Check    = 'Consecutive Layout'
                        Detail   = "3+ consecutive slides with layout '$current' starting at slide $($si - 2). Alternate layouts for visual variety."
                    }
                }
            }
        }

        # --- Check 3: Content density (body/content placeholders only) ---
        foreach ($shape in $slide.Shapes) {
            if ($shape.HasTextFrame -and $shape.Type -eq 14) {
                # Only check body (2) and content (7) placeholders — skip titles, subtitles, statements
                $phType = -1
                try { $phType = $shape.PlaceholderFormat.Type } catch { }
                if ($phType -ne 2 -and $phType -ne 7) { continue }
                try {
                    $range = $shape.TextFrame.TextRange
                    $text = $range.Text.Trim()
                    if ($text) {
                        $paraCount = $range.Paragraphs().Count
                        # Count non-empty paragraphs (bullets)
                        $bulletCount = 0
                        for ($pi = 1; $pi -le $paraCount; $pi++) {
                            $paraText = $range.Paragraphs($pi).Text.Trim()
                            if ($paraText) {
                                $bulletCount++
                                # Check words per bullet
                                $wordCount = ($paraText -split '\s+').Count
                                if ($wordCount -gt 8) {
                                    $slideIssues += [PSCustomObject]@{
                                        Severity = 'Warning'
                                        Check    = 'Content Density'
                                        Detail   = "Shape '$($shape.Name)' paragraph $pi has $wordCount words (max 8 recommended per bullet)"
                                    }
                                }
                            }
                        }
                        if ($bulletCount -gt 6) {
                            $slideIssues += [PSCustomObject]@{
                                Severity = 'Warning'
                                Check    = 'Content Density'
                                Detail   = "Shape '$($shape.Name)' has $bulletCount bullet points (max 6 recommended). Split across multiple slides."
                            }
                        }
                    }
                } catch { }
            }
        }

        # --- Check 4: Empty placeholder text ---
        # Only flag content/body placeholders (type 7) that are empty.
        # Body placeholders (type 2) are often intentionally empty (subtitles, captions, secondary text).
        foreach ($shape in $slide.Shapes) {
            if ($shape.Type -eq 14 -and $shape.HasTextFrame) {
                $isPicturePlaceholder = $false
                try { $isPicturePlaceholder = ($shape.PlaceholderFormat.Type -eq 18) } catch { }
                if (-not $isPicturePlaceholder) {
                    try {
                        $text = $shape.TextFrame.TextRange.Text.Trim()
                        if (-not $text) {
                            $phType = -1
                            try { $phType = $shape.PlaceholderFormat.Type } catch { }
                            # ppPlaceholderObject=7 (main content area)
                            if ($phType -eq 7) {
                                $slideIssues += [PSCustomObject]@{
                                    Severity = 'Warning'
                                    Check    = 'Empty Placeholder'
                                    Detail   = "Content placeholder '$($shape.Name)' is empty. Add content or remove the placeholder."
                                }
                            }
                        }
                    } catch { }
                }
            }
        }

        # --- Check 5: Missing speaker notes ---
        $isSkipLayout = $false
        foreach ($skip in $skipNotesLayouts) {
            if ($layoutName -match [regex]::Escape($skip)) {
                $isSkipLayout = $true
                break
            }
        }
        # Also skip Speaker Card layouts (title/opening slides)
        if ($layoutName -match 'Speaker Card') { $isSkipLayout = $true }

        if (-not $isSkipLayout) {
            $hasNotes = $false
            try {
                $notesText = $slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text.Trim()
                if ($notesText) { $hasNotes = $true }
            } catch { }
            if (-not $hasNotes) {
                $slideIssues += [PSCustomObject]@{
                    Severity = 'Warning'
                    Check    = 'Speaker Notes'
                    Detail   = "No speaker notes on content slide. Add talking points to support the presenter."
                }
            }
        }

        # --- Output slide results ---
        if ($slideIssues.Count -gt 0) {
            Write-Output "Slide ${si}: Layout=`"$layoutName`""
            foreach ($issue in $slideIssues) {
                $prefix = if ($issue.Severity -eq 'Error') { '  [ERROR]  ' } else { '  [WARN]   ' }
                Write-Output "$prefix$($issue.Check): $($issue.Detail)"
            }
            Write-Output ""
        }

        $issues += $slideIssues
    }

    # --- Check 6: Inherited template sections ---
    $sp = $pres.SectionProperties
    if ($sp.Count -gt 0) {
        Write-Output "Presentation-level:"
        for ($secIdx = 1; $secIdx -le $sp.Count; $secIdx++) {
            $secName = $sp.Name($secIdx)
            $issues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Inherited section'; Detail = "Section ${secIdx}: '${secName}' - template metadata section should be removed" }
        }
        Write-Output "  [WARN]   Inherited section: $($sp.Count) slide-sorter section(s) inherited from template."
        Write-Output ""
    }

    # --- Summary ---
    $errors = @($issues | Where-Object { $_.Severity -eq 'Error' })
    $warnings = @($issues | Where-Object { $_.Severity -eq 'Warning' })

    Write-Output "=== Summary ==="
    Write-Output "Errors:   $($errors.Count)"
    Write-Output "Warnings: $($warnings.Count)"
    Write-Output ""

    if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Output "All design quality checks passed."
    } elseif ($errors.Count -eq 0) {
        Write-Output "No errors. Review warnings for improvements."
    } else {
        Write-Output "Fix errors before delivery. Empty image placeholders need images or a layout change."
    }

} finally {
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
    Get-Process POWERPNT -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -notin $existingPPT } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

# Exit code: 0 = clean, 1 = issues found
$exitCode = if ($errors.Count -gt 0) { 1 } else { 0 }
exit $exitCode
