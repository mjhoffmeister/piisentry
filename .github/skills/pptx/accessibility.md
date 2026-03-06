# Accessibility

WCAG 2.1 AA compliance checklist and COM fix patterns for PowerPoint presentations.

---

## Approach: Proactive + QA Pass

Accessibility should be built into your slides during creation, not bolted on after. The skill supports both:

1. **During creation (proactive)**: The content editing patterns in [template-workflow.md](template-workflow.md) and [from-scratch.md](from-scratch.md) include accessibility inline — alt text on images, decorative marking on visual shapes, language setting on text, bold headers on tables. Follow these patterns and most issues are prevented.

2. **After creation (QA pass)**: Run `scripts/Test-Accessibility.ps1 -Fix` to catch and auto-fix anything missed — reading order, font sizes, decorative lines, language, table headers. Remaining issues (alt text, link text, contrast) are reported for manual fix.

This two-layer approach is more efficient than fixing everything retroactively, and produces higher-quality output because alt text is written by whoever knows the content.

---

## Audit Checklist

Run these checks on every presentation before delivery. Use `scripts/Test-Accessibility.ps1` to automate them.

### 1. Slide Titles

Every slide must have a non-empty title for screen reader navigation.

- **Check**: Placeholder type 1 (`ppPlaceholderTitle`) or 3 (`ppPlaceholderCenterTitle`) exists and has non-empty text.
- **Severity**: Error
- **Why**: Screen readers use slide titles to build a navigation outline. Without titles, users cannot jump between slides.

### 2. Image Alt Text

Every image and content shape must have descriptive alt text.

- **Check**: `Shape.AlternativeText` is non-empty for shapes of type `msoPicture` (13), `msoLinkedPicture` (11), `msoPlaceholder` (14) with picture fill, and content shapes (not decorative).
- **Severity**: Error
- **Why**: Screen readers announce alt text. Without it, images are invisible to assistive technology users.

### 3. Decorative Marking

Purely visual shapes (accent bars, background rectangles, divider lines, decorative icons) should be marked decorative.

- **Check**: Shapes that are lines (`msoLine` = 9), freeforms without text, or small rectangles without text should either have `AlternativeText` set or `.Decorative = [int]-1`.
- **Severity**: Warning
- **Why**: Unmarked decorative shapes clutter screen reader output with meaningless announcements.

### 4. Minimum Font Size

No text should be below 18pt in a presentation context.

- **Check**: Every `TextRange` paragraph has `Font.Size >= 18`.
- **Severity**: Warning (Error if below 14pt)
- **Why**: Text below 18pt is difficult to read during presentations, especially on projected screens.

### 5. Hyperlink Text

Link display text must be descriptive — not raw URLs or generic "click here" / "read more".

- **Check**: `Hyperlink.TextToDisplay` is not a URL pattern and is not in the list: "click here", "here", "read more", "link", "more info".
- **Severity**: Warning
- **Why**: Screen readers may read links out of context. "Click here" conveys no meaning when read in a link list.

### 6. Table Headers

Tables must have an identifiable header row.

- **Check**: First row of any `Table` shape has bold text and/or a distinct fill color compared to data rows.
- **Severity**: Warning
- **Why**: Screen readers need header context to make table data meaningful.

### 7. Color Contrast

Text must meet WCAG 2.1 AA contrast ratios against its background.

- **Thresholds**: Normal text (< 24pt, or < 18.5pt bold) requires **4.5:1**. Large text (>= 24pt, or bold >= 18.5pt) requires **3:1**.
- **Check**: Compute relative luminance of text color and background color, calculate contrast ratio.
- **Severity**: Error
- **Why**: Low-contrast text is unreadable for users with low vision or color blindness.

### 8. Reading Order

Shapes must appear in a logical reading sequence: title first, then content top-to-bottom, left-to-right.

- **Check**: `Shape.ZOrderPosition` values follow the expected reading sequence. Title placeholder should have the lowest z-order position among content shapes.
- **Severity**: Warning
- **Why**: Screen readers follow the z-order. Misordered shapes cause confusing, non-sequential reading.

### 9. Slide Language

Text must have its language set so screen readers use correct pronunciation.

- **Check**: `TextRange.LanguageID` is set (not 0 or msoLanguageIDNone).
- **Severity**: Warning
- **Why**: Screen readers mispronounce text when the language is not set or is set incorrectly.

---

## Fix Patterns

COM code snippets to remediate each accessibility issue. See [com-reference.md](com-reference.md) for full API details.

### Set Alt Text on an Image

```powershell
# Describe what the image shows, not "image of..."
$shape.AlternativeText = "Bar chart showing 40% growth in Q4 compared to Q3"

# For complex images, use title + description
$shape.AlternativeTextTitle = "Q4 Revenue Chart"
$shape.AlternativeText = "Vertical bar chart with four bars. Q1: $2.1M, Q2: $2.4M, Q3: $2.8M, Q4: $3.9M. Q4 shows 40% growth."
```

**Tip**: When creating presentations, set alt text during content editing (Step 4 of the workflow) — you already know what each image represents. Don't defer to a separate accessibility pass.

### Mark Shape as Decorative

```powershell
# Mark accent bars, divider lines, background shapes as decorative
$shape.Decorative = [int]-1

# Batch-mark all lines on a slide as decorative
foreach ($shape in $slide.Shapes) {
    if ($shape.Type -eq 9) {  # msoLine
        try { $shape.Decorative = [int]-1 } catch { }
    }
}
```

### Fix Reading Order

```powershell
# Send the title to back (lowest z-order = read first)
$titleShape = $slide.Shapes.Item("Title 1")
$titleShape.ZOrder(1)  # msoSendToBack

# Audit and report current order
$shapes = @()
foreach ($shape in $slide.Shapes) {
    $shapes += [PSCustomObject]@{
        ZOrder = $shape.ZOrderPosition
        Name = $shape.Name
        Top = [math]::Round($shape.Top)
        Left = [math]::Round($shape.Left)
    }
}
$shapes | Sort-Object ZOrder | Format-Table -AutoSize
```

### Set Slide Language

```powershell
# Set English (US) on all text in the presentation
foreach ($slide in $pres.Slides) {
    foreach ($shape in $slide.Shapes) {
        if ($shape.HasTextFrame) {
            $shape.TextFrame.TextRange.LanguageID = 1033
        }
    }
}
```

### Fix Hyperlink Text

```powershell
# Replace raw URL display text with descriptive text
foreach ($shape in $slide.Shapes) {
    if ($shape.HasTextFrame) {
        $range = $shape.TextFrame.TextRange
        for ($i = 1; $i -le $range.Runs().Count; $i++) {
            $run = $range.Runs($i)
            try {
                $link = $run.ActionSettings(1).Hyperlink
                if ($link.Address -and $link.TextToDisplay -match '^https?://') {
                    # Replace URL with domain-based description
                    $uri = [System.Uri]$link.Address
                    $link.TextToDisplay = "Visit $($uri.Host)"
                }
            } catch { }
        }
    }
}
```

### Contrast Ratio Calculation

Use this helper to verify WCAG 2.1 AA contrast between text and background colors.

```powershell
function Get-ContrastRatio {
    param(
        [int]$ForegroundRGB,  # COM RGB value (BGR-packed integer)
        [int]$BackgroundRGB
    )
    
    # Extract R, G, B from COM RGB (stored as B + G*256 + R*65536... but COM actually stores as R + G*256 + B*65536)
    function Get-RelativeLuminance([int]$comRGB) {
        $r = ($comRGB -band 0xFF) / 255.0
        $g = (($comRGB -shr 8) -band 0xFF) / 255.0
        $b = (($comRGB -shr 16) -band 0xFF) / 255.0
        
        # Linearize sRGB
        $r = if ($r -le 0.04045) { $r / 12.92 } else { [math]::Pow((($r + 0.055) / 1.055), 2.4) }
        $g = if ($g -le 0.04045) { $g / 12.92 } else { [math]::Pow((($g + 0.055) / 1.055), 2.4) }
        $b = if ($b -le 0.04045) { $b / 12.92 } else { [math]::Pow((($b + 0.055) / 1.055), 2.4) }
        
        return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
    }
    
    $L1 = Get-RelativeLuminance $ForegroundRGB
    $L2 = Get-RelativeLuminance $BackgroundRGB
    
    $lighter = [math]::Max($L1, $L2)
    $darker = [math]::Min($L1, $L2)
    
    return ($lighter + 0.05) / ($darker + 0.05)
}

# Usage:
$ratio = Get-ContrastRatio -ForegroundRGB $textColor -BackgroundRGB $bgColor
$passes = if ($fontSize -ge 24 -or ($fontSize -ge 18.5 -and $isBold)) {
    $ratio -ge 3.0    # Large text threshold
} else {
    $ratio -ge 4.5    # Normal text threshold
}
Write-Output "Contrast ratio: $([math]::Round($ratio, 2)):1 — $(if ($passes) {'PASS'} else {'FAIL'})"
```

---

## Best Practices

1. **Set alt text during content creation**, not as an afterthought. You know what each element represents when you create it.
2. **Mark decorative shapes immediately** when adding accent bars, divider lines, or background shapes.
3. **Set language in your edit script** — add a language-setting loop at the end of your COM edit block (shown in the template-workflow.md and from-scratch.md skeletons).
4. **Use the template's built-in title placeholders** — don't delete them and add text boxes instead.
5. **Run `Test-Accessibility.ps1 -Fix`** as the last step before delivery. It fixes reading order, font sizes, decorative lines, language, and table headers automatically.
6. **Provide context in alt text** — describe what the data shows, not just "chart" or "diagram".
7. **Keep slide count reasonable** — more slides with less content beats fewer slides with walls of text (better for screen readers too).
