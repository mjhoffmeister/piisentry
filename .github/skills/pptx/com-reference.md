# COM Automation Reference

Quick reference for PowerPoint COM objects and patterns used by this skill.

---

## Object Hierarchy

```
Application
└── Presentations
    └── Presentation
        ├── PageSetup (SlideWidth, SlideHeight)
        ├── Designs                              ← Use instead of SlideMasters
        │   └── Design
        │       ├── Name
        │       └── SlideMaster
        │           └── CustomLayouts
        │               └── CustomLayout (Name, Index)
        ├── SlideMasters                         ← .Count returns 0 in COM interop — avoid
        └── Slides
            └── Slide
                ├── SlideIndex
                ├── CustomLayout
                ├── SlideShowTransition (Hidden)
                └── Shapes
                    └── Shape
                        ├── Name, Type
                        ├── Left, Top, Width, Height
                        ├── PlaceholderFormat (Type)
                        ├── TextFrame
                        │   └── TextRange
                        │       ├── Text
                        │       ├── Font (Name, Size, Bold, Italic, Color)
                        │       ├── ParagraphFormat (Alignment, Bullet)
                        │       └── Paragraphs(index)
                        ├── Fill (ForeColor, Solid, Visible)
                        └── Line (ForeColor, Weight, Visible)
```

---

## Opening and Closing

### Open Existing (Read-Only, No Window)

```powershell
$app = New-Object -ComObject PowerPoint.Application

# Open(FileName, ReadOnly, Untitled, WithWindow)
# MsoTriState: msoTrue = -1, msoFalse = 0
$pres = $app.Presentations.Open($fullPath, [int]-1, [int]0, [int]0)
```

### Open for Editing

```powershell
$pres = $app.Presentations.Open($fullPath, [int]0, [int]0, [int]0)
```

### Create New Blank

```powershell
$pres = $app.Presentations.Add($false)  # $false = no window
```

### Save

```powershell
$pres.Save()                    # Save in place
$pres.SaveAs($path, 24)        # ppSaveAsOpenXMLPresentation = 24
```

### Close and Cleanup (CRITICAL)

```powershell
# Track existing PowerPoint processes before starting
$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)

# ... your COM work here, wrapped in try/finally ...

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
```

**Always use try/finally** to ensure cleanup runs even on errors. Null-check `$pres` and `$app` — if creation fails, calling `.Close()` on `$null` throws and masks the real error.

### Verifying Saves

COM methods throw on failure, so a successful `Save()` / `SaveAs()` return means the file was written. Add a confirmation message after saving so success is visible in the output:

```powershell
$pres.Save()
Write-Host "Saved: $($pres.FullName)"
```

For extra assurance after `SaveAs()` to a new path:

```powershell
$pres.SaveAs($outputPath, 24)
Write-Host "Saved: $outputPath"
```

---

## Enumeration Values

### Placeholder Types (ppPlaceholderType)

| Value | Name | Description |
|-------|------|-------------|
| 1 | ppPlaceholderTitle | Title |
| 2 | ppPlaceholderBody | Body/content |
| 3 | ppPlaceholderCenterTitle | Center title |
| 12 | ppPlaceholderSubtitle | Subtitle |
| 13 | ppPlaceholderDate | Date |
| 14 | ppPlaceholderSlideNumber | Slide number |
| 15 | ppPlaceholderFooter | Footer |

### Save Formats (ppSaveAsFileType)

| Value | Name | Extension |
|-------|------|-----------|
| 24 | ppSaveAsOpenXMLPresentation | .pptx |
| 32 | ppSaveAsPDF | .pdf |
| 17 | ppSaveAsJPG | .jpg |
| 18 | ppSaveAsPNG | .png |

### Shape Types (msoShapeType)

| Value | Name |
|-------|------|
| 1 | msoShapeRectangle |
| 5 | msoShapeRoundedRectangle |
| 9 | msoShapeOval |
| 13 | msoFreeform |
| 14 | msoGroup |

### Text Alignment (ppParagraphAlignment)

| Value | Name |
|-------|------|
| 1 | ppAlignLeft |
| 2 | ppAlignCenter |
| 3 | ppAlignRight |
| 4 | ppAlignJustify |

### Bullet Type (ppBulletType)

| Value | Name |
|-------|------|
| 0 | ppBulletNone |
| 1 | ppBulletUnnumbered |
| 2 | ppBulletNumbered |

---

## Common Patterns

### Iterate All Shapes on a Slide

```powershell
foreach ($shape in $slide.Shapes) {
    Write-Output "$($shape.Name): Type=$($shape.Type)"
    if ($shape.HasTextFrame) {
        Write-Output "  Text: $($shape.TextFrame.TextRange.Text)"
    }
}
```

### Find Shape by Name

```powershell
$shape = $slide.Shapes.Item("Title 1")
```

### Find Placeholder by Type

```powershell
foreach ($shape in $slide.Shapes) {
    try {
        if ($shape.PlaceholderFormat.Type -eq 1) {  # Title
            $shape.TextFrame.TextRange.Text = "New Title"
        }
    } catch { }
}
```

### Set RGB Color

```powershell
# Using System.Drawing (readable)
$rgb = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(30, 39, 97))
$shape.Fill.ForeColor.RGB = $rgb

# Direct calculation: R + (G * 256) + (B * 65536)
# Note: COM uses BGR order internally
$shape.Fill.ForeColor.RGB = 0x1E + (0x27 -shl 8) + (0x61 -shl 16)
```

### Export Slide to Image

```powershell
$slide.Export("C:\path\slide1.jpg", "JPG", 1920, 1080)
```

### Speaker Notes

```powershell
# Set speaker notes for a slide
$slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "Notes text here"

# Read existing speaker notes
$notes = $slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text

# Multi-paragraph notes
$notesRange = $slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange
$notesRange.Text = "Key point to elaborate on.`r`nMention the customer case study.`r`nTransition: ask the audience about their experience."

# Format notes text (rarely needed — notes are for the presenter, not projected)
$notesRange.Font.Size = 12
```

> **Note:** The notes placeholder is always `Placeholders.Item(2)` on the notes page. `Item(1)` is the slide thumbnail.

---

## Accessibility Properties

### Alt Text

Every non-decorative image and content shape needs alt text for screen readers.

```powershell
# Set alt text on a shape or picture
$shape.AlternativeText = "Bar chart showing quarterly revenue growth from Q1 to Q4"

# Optional: set alt text title (appears in the alt text pane header)
$shape.AlternativeTextTitle = "Revenue Chart"

# Read existing alt text
$altText = $shape.AlternativeText
```

### Decorative Marking

Shapes that are purely visual (accent bars, background rectangles, divider lines) should be marked decorative so screen readers skip them. Requires Office 365 / 2019+.

```powershell
# Mark as decorative (uses MsoTriState: -1 = true, 0 = false)
$shape.Decorative = [int]-1

# Check if decorative
if ($shape.Decorative -eq -1) { Write-Output "Decorative" }

# Note: setting Decorative clears AlternativeText automatically
```

> **Compatibility:** `Shape.Decorative` throws a COM exception on Office 2016 and earlier. Wrap in `try/catch` when targeting mixed environments.

### Reading Order (Z-Order)

Screen readers follow the z-order (tab order) of shapes. Title should be first (lowest z-order position), then content top-to-bottom, left-to-right.

```powershell
# Read current z-order position (1-based, lower = read first)
$position = $shape.ZOrderPosition

# Reorder shapes
$shape.ZOrder(0)  # msoBringToFront
$shape.ZOrder(1)  # msoSendToBack
$shape.ZOrder(2)  # msoBringForward (one step)
$shape.ZOrder(3)  # msoSendBackward (one step)

# Audit reading order for a slide
foreach ($shape in $slide.Shapes) {
    Write-Output "Z=$($shape.ZOrderPosition) Name=$($shape.Name)"
}
```

### Slide Language

Set the language so screen readers use correct pronunciation rules.

```powershell
# Set language on a text range (1033 = English US)
$shape.TextFrame.TextRange.LanguageID = 1033

# Common language IDs:
# 1033 = English (US)       2057 = English (UK)
# 1031 = German             1036 = French
# 1034 = Spanish            1041 = Japanese

# Set language for all text on a slide
foreach ($shape in $slide.Shapes) {
    if ($shape.HasTextFrame) {
        $shape.TextFrame.TextRange.LanguageID = 1033
    }
}
```

### Hyperlink Accessibility

Link display text should be descriptive, not raw URLs or "click here".

```powershell
# Get hyperlinks from a text range
$hyperlinks = $shape.TextFrame.TextRange.ActionSettings(1).Hyperlink

# Set descriptive display text
$hyperlinks.TextToDisplay = "View the accessibility guidelines"
$hyperlinks.Address = "https://www.w3.org/WAI/WCAG21/quickref/"

# Audit all hyperlinks on a slide
foreach ($shape in $slide.Shapes) {
    if ($shape.HasTextFrame) {
        $range = $shape.TextFrame.TextRange
        for ($i = 1; $i -le $range.Runs().Count; $i++) {
            $run = $range.Runs($i)
            try {
                $link = $run.ActionSettings(1).Hyperlink
                if ($link.Address) {
                    Write-Output "Link: '$($link.TextToDisplay)' -> $($link.Address)"
                }
            } catch { }
        }
    }
}
```

### Slide Title Verification

Every slide must have a title for screen reader navigation.

```powershell
# Check if a slide has a title placeholder with content
$hasTitle = $false
foreach ($shape in $slide.Shapes) {
    try {
        $phType = $shape.PlaceholderFormat.Type
        if ($phType -eq 1 -or $phType -eq 3) {  # ppPlaceholderTitle or ppPlaceholderCenterTitle
            if ($shape.HasTextFrame -and $shape.TextFrame.TextRange.Text.Trim()) {
                $hasTitle = $true
            }
        }
    } catch { }
}
```

---

## Gotchas

### COM Object Cleanup

Unreleased COM objects leave `POWERPNT.EXE` running in the background, locking files. **Always** release in a `finally` block.

If a script crashes and leaves an orphaned process:
```powershell
Get-Process POWERPNT -ErrorAction SilentlyContinue | Stop-Process -Force
```

### File Paths Must Be Absolute

COM methods require absolute file paths. Use `Resolve-Path` or `Join-Path (Get-Location)` before passing paths.

### MsoTriState

Many COM properties use `MsoTriState` instead of boolean:
- `msoTrue` = -1
- `msoFalse` = 0
- `msoCTrue` = 1 (for "calculated true")

Use integer values: `[int]-1` for true, `[int]0` for false.

### Read-Only and WithWindow

- **WithWindow must be msoTrue** for `Slide.Export()` and `Slide.Duplicate()` to work.
- **ReadOnly must be msoFalse** for `Slide.Duplicate()`, `Slide.Delete()`, and `Slide.MoveTo()`.
- **`$app.Visible = [int]-1`** must be set for Export and Duplicate operations.
- Opening without a window (`WithWindow = msoFalse`) works for read-only analysis (e.g., shape enumeration), but not for export or mutation.

### SlideMasters vs Designs

`$pres.SlideMasters.Count` returns 0 in PowerShell COM interop. Access layouts through Designs instead:

```powershell
# WRONG — returns 0:
$pres.SlideMasters.Count

# CORRECT — use Designs:
$master = $pres.Designs.Item(1).SlideMaster
$master.CustomLayouts.Item(1).Name  # "Title Slide"
```

### COM Collection Iteration

`foreach` does not always work on COM collections (e.g., SlideMasters). Use indexed `for` loops:

```powershell
# WRONG — may silently iterate zero times:
foreach ($master in $pres.SlideMasters) { ... }

# CORRECT:
for ($i = 1; $i -le $pres.Designs.Count; $i++) {
    $design = $pres.Designs.Item($i)
}
```

Note: `foreach` works reliably on `Slide.Shapes` but not on all collections.

### Integer Arguments for COM Methods

JSON-parsed values and some PowerShell expressions return `[long]` or `[decimal]`, which COM rejects. Cast to `[int]`:

```powershell
# WRONG — "Bad argument type" error:
$pres.Slides.Item($entry.source)

# CORRECT:
$pres.Slides.Item([int]$entry.source)
```

### Shape Coordinates

All coordinates (Left, Top, Width, Height) are in **points** (1 inch = 72 points).

| Inches | Points |
|--------|--------|
| 0.5 | 36 |
| 1 | 72 |
| 2 | 144 |
| 5 | 360 |
| 10 | 720 |
| 13.33 | 960 |
