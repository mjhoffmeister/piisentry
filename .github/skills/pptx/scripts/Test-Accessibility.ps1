<#
.SYNOPSIS
    Audits a PowerPoint presentation for accessibility issues.

.DESCRIPTION
    Opens a .pptx file via COM automation and checks for WCAG 2.1 AA compliance:
    - Slide titles present and non-empty
    - Alt text on images and content shapes
    - Decorative marking on visual-only shapes
    - Minimum font size (18pt)
    - Descriptive hyperlink text
    - Table header row identification
    - Reading order (z-order)
    - Slide language set

    Outputs a per-slide report of issues found with severity (Error/Warning)
    and remediation guidance.

.PARAMETER Path
    Path to the .pptx file to audit.

.PARAMETER Fix
    Switch to auto-fix issues that can be resolved without human judgment:
    - Set language (LanguageID 1033) on all text without a language
    - Mark line shapes (msoLine) as decorative
    - Fix reading order (send title placeholder to back of z-order)
    - Bump font sizes below 14pt up to 18pt
    - Bold the first row of tables missing header formatting
    Does NOT auto-fix alt text or link text (requires human judgment).

.EXAMPLE
    .\Test-Accessibility.ps1 -Path "output/My-Deck/My-Deck.pptx"

.EXAMPLE
    .\Test-Accessibility.ps1 -Path "output/My-Deck/My-Deck.pptx" -Fix
#>
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$Fix
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

# --- Helpers ---

function Get-RelativeLuminance([int]$comRGB) {
    $r = ($comRGB -band 0xFF) / 255.0
    $g = (($comRGB -shr 8) -band 0xFF) / 255.0
    $b = (($comRGB -shr 16) -band 0xFF) / 255.0

    $r = if ($r -le 0.04045) { $r / 12.92 } else { [math]::Pow((($r + 0.055) / 1.055), 2.4) }
    $g = if ($g -le 0.04045) { $g / 12.92 } else { [math]::Pow((($g + 0.055) / 1.055), 2.4) }
    $b = if ($b -le 0.04045) { $b / 12.92 } else { [math]::Pow((($b + 0.055) / 1.055), 2.4) }

    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Get-ContrastRatio([int]$fg, [int]$bg) {
    $L1 = Get-RelativeLuminance $fg
    $L2 = Get-RelativeLuminance $bg
    $lighter = [math]::Max($L1, $L2)
    $darker = [math]::Min($L1, $L2)
    return ($lighter + 0.05) / ($darker + 0.05)
}

$badLinkPatterns = @('^https?://', '^www\.', '^click here$', '^here$', '^read more$', '^link$', '^more info$', '^more$')

# --- COM Setup ---

$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$app = $null
$pres = $null
$issues = @()
$fixCount = 0

try {
    $app = New-Object -ComObject PowerPoint.Application

    if ($Fix) {
        # Open read-write for fixes
        $pres = $app.Presentations.Open($resolvedPath.Path)
    } else {
        # Open read-only
        $pres = $app.Presentations.Open($resolvedPath.Path, [int]-1, [int]0, [int]0)
    }

    Write-Output "=== Accessibility Audit ==="
    Write-Output "File: $resolvedPath"
    Write-Output "Slides: $($pres.Slides.Count)"
    Write-Output ""

    for ($si = 1; $si -le $pres.Slides.Count; $si++) {
        $slide = $pres.Slides.Item($si)
        $slideIssues = @()

        # --- Check 1: Slide title ---
        $hasTitle = $false
        foreach ($shape in $slide.Shapes) {
            try {
                $phType = $shape.PlaceholderFormat.Type
                if ($phType -eq 1 -or $phType -eq 3) {
                    if ($shape.HasTextFrame -and $shape.TextFrame.TextRange.Text.Trim()) {
                        $hasTitle = $true
                    }
                }
            } catch { }
        }
        if (-not $hasTitle) {
            $slideIssues += [PSCustomObject]@{ Severity = 'Error'; Check = 'Slide Title'; Detail = 'No title placeholder with text found' }
        }

        # --- Per-shape checks ---
        foreach ($shape in $slide.Shapes) {
            $shapeName = $shape.Name
            $shapeType = $shape.Type

            # Check 2: Alt text on images
            # msoPicture=13, msoLinkedPicture=11
            if ($shapeType -eq 13 -or $shapeType -eq 11) {
                $isDecorative = $false
                try { $isDecorative = ($shape.Decorative -eq -1) } catch { }
                if (-not $isDecorative -and -not $shape.AlternativeText) {
                    $slideIssues += [PSCustomObject]@{ Severity = 'Error'; Check = 'Alt Text'; Detail = "Image '$shapeName' has no alt text" }
                }
            }

            # Check 3: Decorative marking for visual-only shapes
            # msoLine=9
            if ($shapeType -eq 9) {
                $isDecorative = $false
                try { $isDecorative = ($shape.Decorative -eq -1) } catch { }
                $hasAlt = [bool]$shape.AlternativeText
                if (-not $isDecorative -and -not $hasAlt) {
                    $slideIssues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Decorative'; Detail = "Line '$shapeName' not marked decorative and has no alt text" }
                    if ($Fix) {
                        try {
                            $shape.Decorative = [int]-1
                            $fixCount++
                        } catch {
                            $slideIssues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Decorative'; Detail = "Could not mark '$shapeName' as decorative (Office version may not support Shape.Decorative)" }
                        }
                    }
                }
            }

            # Check 4: Minimum font size
            if ($shape.HasTextFrame) {
                try {
                    $range = $shape.TextFrame.TextRange
                    if ($range.Text.Trim()) {
                        for ($pi = 1; $pi -le $range.Paragraphs().Count; $pi++) {
                            $para = $range.Paragraphs($pi)
                            if ($para.Text.Trim()) {
                                $fontSize = $para.Font.Size
                                if ($fontSize -gt 0 -and $fontSize -lt 14) {
                                    $slideIssues += [PSCustomObject]@{ Severity = 'Error'; Check = 'Font Size'; Detail = "Shape '$shapeName' paragraph $pi has ${fontSize}pt text (minimum 14pt)" }
                                    if ($Fix) {
                                        $para.Font.Size = 18
                                        $fixCount++
                                    }
                                } elseif ($fontSize -gt 0 -and $fontSize -lt 18) {
                                    $slideIssues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Font Size'; Detail = "Shape '$shapeName' paragraph $pi has ${fontSize}pt text (recommended minimum 18pt)" }
                                }
                            }
                        }
                    }
                } catch { }
            }

            # Check 5: Hyperlink text
            if ($shape.HasTextFrame) {
                try {
                    $range = $shape.TextFrame.TextRange
                    for ($ri = 1; $ri -le $range.Runs().Count; $ri++) {
                        $run = $range.Runs($ri)
                        try {
                            $link = $run.ActionSettings(1).Hyperlink
                            if ($link.Address) {
                                $displayText = $link.TextToDisplay
                                foreach ($pattern in $badLinkPatterns) {
                                    if ($displayText -match $pattern) {
                                        $slideIssues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Link Text'; Detail = "Shape '$shapeName' has non-descriptive link text: '$displayText'" }
                                        break
                                    }
                                }
                            }
                        } catch { }
                    }
                } catch { }
            }

            # Check 6: Table headers
            if ($shapeType -eq 19) {  # msoTable
                try {
                    $table = $shape.Table
                    if ($table.Rows.Count -ge 2) {
                        $headerBold = $true
                        for ($col = 1; $col -le $table.Columns.Count; $col++) {
                            $cell = $table.Cell(1, $col)
                            if (-not $cell.Shape.TextFrame.TextRange.Font.Bold) {
                                $headerBold = $false
                                break
                            }
                        }
                        if (-not $headerBold) {
                            $slideIssues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Table Header'; Detail = "Table '$shapeName' header row is not bold - may not be identifiable as header" }
                            if ($Fix) {
                                for ($fixCol = 1; $fixCol -le $table.Columns.Count; $fixCol++) {
                                    $table.Cell(1, $fixCol).Shape.TextFrame.TextRange.Font.Bold = $true
                                }
                                $fixCount++
                            }
                        }
                    }
                } catch { }
            }

            # Check 9: Language
            if ($shape.HasTextFrame) {
                try {
                    $langId = $shape.TextFrame.TextRange.LanguageID
                    if ($langId -eq 0) {
                        $slideIssues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Language'; Detail = "Shape '$shapeName' has no language set" }
                        if ($Fix) {
                            $shape.TextFrame.TextRange.LanguageID = 1033
                            $fixCount++
                        }
                    }
                } catch { }
            }

            # Check 7: Contrast (text on shape fill)
            if ($shape.HasTextFrame) {
                try {
                    $range = $shape.TextFrame.TextRange
                    if ($range.Text.Trim()) {
                        $textColor = $range.Font.Color.RGB
                        $bgColor = $null

                        # Try shape fill first
                        try {
                            if ($shape.Fill.Visible) {
                                $bgColor = $shape.Fill.ForeColor.RGB
                            }
                        } catch { }

                        # Fall back to slide background
                        if ($null -eq $bgColor) {
                            try {
                                $bgColor = $slide.Background.Fill.ForeColor.RGB
                            } catch { }
                        }

                        if ($null -ne $bgColor -and $null -ne $textColor) {
                            $ratio = Get-ContrastRatio $textColor $bgColor
                            $fontSize = $range.Font.Size
                            $isBold = $range.Font.Bold
                            $isLarge = ($fontSize -ge 24) -or ($fontSize -ge 18.5 -and $isBold)
                            $threshold = if ($isLarge) { 3.0 } else { 4.5 }

                            if ($ratio -lt $threshold) {
                                $roundedRatio = [math]::Round($ratio, 2)
                                $slideIssues += [PSCustomObject]@{ Severity = 'Error'; Check = 'Contrast'; Detail = "Shape '$shapeName' contrast ratio ${roundedRatio}:1 below ${threshold}:1 threshold" }
                            }
                        }
                    }
                } catch { }
            }
        }

        # Check 8: Reading order
        $contentShapes = @()
        foreach ($shape in $slide.Shapes) {
            $isDecorative = $false
            try { $isDecorative = ($shape.Decorative -eq -1) } catch { }
            if (-not $isDecorative) {
                $isTitle = $false
                try { $isTitle = ($shape.PlaceholderFormat.Type -eq 1 -or $shape.PlaceholderFormat.Type -eq 3) } catch { }
                $contentShapes += [PSCustomObject]@{
                    Name = $shape.Name
                    ZOrder = $shape.ZOrderPosition
                    IsTitle = $isTitle
                    Top = $shape.Top
                }
            }
        }
        if ($contentShapes.Count -gt 1) {
            $titleShape = $contentShapes | Where-Object { $_.IsTitle }
            if ($titleShape) {
                $minZ = ($contentShapes | Measure-Object -Property ZOrder -Minimum).Minimum
                if ($titleShape.ZOrder -ne $minZ) {
                    $slideIssues += [PSCustomObject]@{ Severity = 'Warning'; Check = 'Reading Order'; Detail = "Title is not first in reading order (z-order $($titleShape.ZOrder), minimum is $minZ)" }
                    if ($Fix) {
                        # Find the actual title shape COM object and send to back
                        foreach ($shape in $slide.Shapes) {
                            try {
                                $phType = $shape.PlaceholderFormat.Type
                                if ($phType -eq 1 -or $phType -eq 3) {
                                    $shape.ZOrder(1)  # msoSendToBack
                                    $fixCount++
                                    break
                                }
                            } catch { }
                        }
                    }
                }
            }
        }

        # --- Output slide results ---
        if ($slideIssues.Count -gt 0) {
            Write-Output "Slide ${si}:"
            foreach ($issue in $slideIssues) {
                $prefix = if ($issue.Severity -eq 'Error') { '  [ERROR]  ' } else { '  [WARN]   ' }
                Write-Output "$prefix$($issue.Check): $($issue.Detail)"
            }
            Write-Output ""
        }

        $issues += $slideIssues
    }

    # --- Summary ---
    $errors = @($issues | Where-Object { $_.Severity -eq 'Error' })
    $warnings = @($issues | Where-Object { $_.Severity -eq 'Warning' })

    Write-Output "=== Summary ==="
    Write-Output "Errors:   $($errors.Count)"
    Write-Output "Warnings: $($warnings.Count)"
    if ($Fix) {
        Write-Output "Auto-fixed: $fixCount"
    }
    Write-Output ""

    if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Output "All checks passed."
    } elseif ($errors.Count -eq 0) {
        Write-Output "No errors. Review warnings for improvements."
    } else {
        Write-Output "Fix errors before delivery. See accessibility.md for remediation patterns."
    }

    if ($Fix -and $fixCount -gt 0) {
        $pres.Save()
        Write-Host "Saved: $($pres.FullName)"
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
