# Creating from Scratch

Use this when no template or reference presentation is available.

## Workflow

1. Create a new blank presentation via COM
2. Add slides with desired layouts
3. Populate content, speaker notes, and alt text during creation
4. Visual QA with `Export-SlideThumbnails.ps1`
5. Accessibility check with `Test-Accessibility.ps1` (see [accessibility.md](accessibility.md))

---

## Basic Structure

```powershell
$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$app = New-Object -ComObject PowerPoint.Application
$pres = $app.Presentations.Add($false)  # $false = no window

try {
    # Set slide size (widescreen 16:9)
    $pres.PageSetup.SlideWidth = 960    # 13.33 inches * 72
    $pres.PageSetup.SlideHeight = 540   # 7.5 inches * 72

    # --- Build slides here ---

    # --- Accessibility: set language on all text ---
    foreach ($slide in $pres.Slides) {
        foreach ($shape in $slide.Shapes) {
            if ($shape.HasTextFrame) {
                $shape.TextFrame.TextRange.LanguageID = 1033  # English (US)
            }
        }
    }

    # ppSaveAsOpenXMLPresentation = 24
    $outputPath = "$(Join-Path (Get-Location) 'output/My-Deck/My-Deck.pptx')"
    $pres.SaveAs($outputPath, 24)
    Write-Host "Saved: $outputPath"
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
    Get-Process POWERPNT -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -notin $existingPPT } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
```

---

## Adding Slides

### Method 1: By Layout Type Enum (simplest)

```powershell
# Common ppSlideLayout enum values
# 1  = ppLayoutTitle          (title + subtitle)
# 2  = ppLayoutText           (title + body text)
# 3  = ppLayoutTwoColumnText  (title + two text columns)
# 7  = ppLayoutOrgchart       (organization chart)
# 11 = ppLayoutTitleOnly      (title only)
# 12 = ppLayoutBlank          (blank)

$slide = $pres.Slides.Add(1, 1)   # Add title slide at position 1
$slide = $pres.Slides.Add(2, 2)   # Add text slide at position 2
$slide = $pres.Slides.Add(3, 12)  # Add blank slide at position 3
```

### Method 2: By Custom Layout Object (for named layouts)

```powershell
# NOTE: Use Designs, not SlideMasters — SlideMasters.Count returns 0 in COM interop
$layout = $pres.Designs.Item(1).SlideMaster.CustomLayouts.Item(1)
$slide = $pres.Slides.AddSlide($pres.Slides.Count + 1, $layout)
```

To list all available layouts:

```powershell
$master = $pres.Designs.Item(1).SlideMaster
for ($i = 1; $i -le $master.CustomLayouts.Count; $i++) {
    $layout = $master.CustomLayouts.Item($i)
    Write-Output "Layout [$i]: $($layout.Name)"
}
```

---

## Text and Formatting

### Add a Text Box

```powershell
# AddTextbox(Orientation, Left, Top, Width, Height) — coordinates in points (72 pts = 1 inch)
$textbox = $slide.Shapes.AddTextbox(1, 72, 72, 720, 50)  # msoTextOrientationHorizontal = 1
$textbox.TextFrame.TextRange.Text = "Hello World"
$textbox.TextFrame.TextRange.Font.Size = 36
$textbox.TextFrame.TextRange.Font.Name = "Calibri"
$textbox.TextFrame.TextRange.Font.Bold = $true
```

### Set Font Color

```powershell
# RGB color (use System.Drawing.Color for readability)
$range = $textbox.TextFrame.TextRange
$range.Font.Color.RGB = [System.Drawing.ColorTranslator]::ToOle(
    [System.Drawing.Color]::FromArgb(30, 39, 97)
)

# Or compute directly: R + (G * 256) + (B * 65536)
$range.Font.Color.RGB = 0x1E + (0x27 -shl 8) + (0x61 -shl 16)
```

### Multi-Line Text

```powershell
$textbox.TextFrame.TextRange.Text = "Line 1`r`nLine 2`r`nLine 3"

# Format individual paragraphs
$textbox.TextFrame.TextRange.Paragraphs(1).Font.Bold = $true
$textbox.TextFrame.TextRange.Paragraphs(1).Font.Size = 24
```

### Bulleted and Numbered Lists

```powershell
$tf = $textbox.TextFrame.TextRange
$tf.Text = "First item`r`nSecond item`r`nThird item"

# Bullets
$tf.ParagraphFormat.Bullet.Type = 1  # ppBulletUnnumbered

# Numbered
$tf.ParagraphFormat.Bullet.Type = 2  # ppBulletNumbered
$tf.ParagraphFormat.Bullet.Style = 1 # ppBulletArabicPeriod
```

### Text Box Sizing

```powershell
$textbox.TextFrame.AutoSize = 0  # ppAutoSizeNone — fixed size
$textbox.TextFrame.AutoSize = 1  # ppAutoSizeShapeToFitText — shrink box to fit
$textbox.TextFrame.WordWrap = $true
```

---

## Shapes

### Rectangle

```powershell
# AddShape(Type, Left, Top, Width, Height)
$rect = $slide.Shapes.AddShape(1, 72, 72, 360, 216)  # msoShapeRectangle = 1
$rect.Fill.ForeColor.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(6, 90, 130))
$rect.Line.Visible = $false
```

### Rounded Rectangle

```powershell
$rrect = $slide.Shapes.AddShape(5, 72, 72, 360, 216)  # msoShapeRoundedRectangle = 5
$rrect.Fill.ForeColor.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::White)
$rrect.Line.ForeColor.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::LightGray)
$rrect.Line.Weight = 1
```

### Line

```powershell
# AddLine(BeginX, BeginY, EndX, EndY)
$line = $slide.Shapes.AddLine(72, 300, 888, 300)
$line.Line.ForeColor.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::Gray)
$line.Line.Weight = 2
try { $line.Decorative = [int]-1 } catch { }  # Mark decorative — screen readers skip it
```

### Shape with Text

```powershell
$shape = $slide.Shapes.AddShape(1, 100, 100, 200, 100)
$shape.Fill.ForeColor.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(2, 128, 144))
$shape.TextFrame.TextRange.Text = "Label"
$shape.TextFrame.TextRange.Font.Color.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::White)
$shape.TextFrame.TextRange.Font.Size = 16
$shape.TextFrame.TextRange.ParagraphFormat.Alignment = 2  # ppAlignCenter
```

---

## Images

```powershell
# AddPicture(FileName, LinkToFile, SaveWithDocument, Left, Top, Width, Height)
$pic = $slide.Shapes.AddPicture(
    "$(Resolve-Path logo.png)",
    $false,  # Don't link to file
    $true,   # Embed in presentation
    72,      # Left
    72,      # Top
    200,     # Width
    100      # Height
)
$pic.AlternativeText = "Company logo — Contoso horizontal wordmark"
```

> **Always set alt text** on images and content shapes at creation time. You know what the image represents — don't defer to a separate accessibility pass.

### Preserve Aspect Ratio

```powershell
$pic.LockAspectRatio = $true
$pic.Width = 200  # Height adjusts automatically
```

---

## Speaker Notes

Speaker notes provide the presenter's narrative — the context, stories, and transitions that bring flat slides to life. Not every slide needs notes; title slides and closing slides usually don't.

```powershell
# Set notes for a slide
$slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = @"
Explain why this architecture was chosen over the alternatives.
Mention the 40% latency reduction from the customer pilot.
Transition: "Let's look at how this works in practice..."
"@
```

See the [Speaker Notes Guide](#writing-good-speaker-notes) in the Design Guidance section below for what to include.

```powershell
# Solid color background
$slide.FollowMasterBackground = $false
$slide.Background.Fill.Solid()
$slide.Background.Fill.ForeColor.RGB = [System.Drawing.ColorTranslator]::ToOle(
    [System.Drawing.Color]::FromArgb(30, 39, 97)
)
```

---

## Tables

```powershell
# AddTable(NumRows, NumColumns, Left, Top, Width, Height)
$tableShape = $slide.Shapes.AddTable(4, 3, 72, 150, 816, 300)
$table = $tableShape.Table

# Set cell content
$table.Cell(1, 1).Shape.TextFrame.TextRange.Text = "Name"
$table.Cell(1, 2).Shape.TextFrame.TextRange.Text = "Role"
$table.Cell(1, 3).Shape.TextFrame.TextRange.Text = "Status"

# Format header row
for ($col = 1; $col -le 3; $col++) {
    $cell = $table.Cell(1, $col)
    $cell.Shape.TextFrame.TextRange.Font.Bold = $true
    $cell.Shape.TextFrame.TextRange.Font.Size = 14
    $cell.Shape.TextFrame.TextRange.Font.Color.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::White)
    $cell.Shape.Fill.ForeColor.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(6, 90, 130))
}
```

---

## Design Guidance

### Before Starting

- **Pick a color palette** that fits the topic — don't default to generic blue
- **Choose a dominant color** (60-70% visual weight) with 1-2 supporting tones and one accent
- **Use dark/light contrast** — dark backgrounds for title + conclusion slides, light for content
- **Pick a visual motif** and repeat it — rounded image frames, accent bars, icon circles

### Color Palettes

| Theme | Primary | Secondary | Accent | WCAG AA Verified Combos |
|-------|---------|-----------|--------|-------------------------|
| **Deep Navy** | `1E2761` | `CADCFC` | `FFFFFF` | White on Primary (11.5:1 ✓), Primary on Secondary (5.2:1 ✓) |
| **Forest** | `2C5F2D` | `97BC62` | `F5F5F5` | Accent on Primary (7.9:1 ✓), Primary on Accent (7.9:1 ✓) |
| **Warm Clay** | `B85042` | `E7E8D1` | `A7BEAE` | White on Primary (4.5:1 ✓), Primary on Secondary (4.8:1 ✓) |
| **Ocean** | `065A82` | `1C7293` | `21295C` | White on Primary (5.8:1 ✓), White on Accent (12.1:1 ✓) |
| **Charcoal** | `36454F` | `F2F2F2` | `212121` | Accent on Secondary (12.4:1 ✓), Secondary on Accent (12.4:1 ✓) |
| **Teal** | `028090` | `00A896` | `02C39A` | White on Primary (4.6:1 ✓), Black on Secondary (4.7:1 ✓) |
| **Berry** | `6D2E46` | `A26769` | `ECE2D0` | Accent on Primary (5.3:1 ✓), White on Primary (7.1:1 ✓) |
| **Sage** | `84B59F` | `69A297` | `50808E` | White on Accent (4.5:1 ✓), Black on Primary (5.8:1 ✓) |

> Use the verified combos to ensure WCAG 2.1 AA compliance (4.5:1 for normal text, 3:1 for large text ≥ 24pt or bold ≥ 18.5pt). See [accessibility.md](accessibility.md) for the contrast ratio formula.

### Font Size Hierarchy

| Element | Minimum Size | Recommended |
|---------|-------------|-------------|
| Title | 28pt | 32-44pt |
| Subtitle | 22pt | 24-28pt |
| Body | 18pt | 20-24pt |
| Caption | 14pt | 14-16pt (non-essential text only) |

Never go below 18pt for primary content. 14pt is acceptable only for supplementary captions and footnotes.

### Content Density

- **Max 6 bullet points** per slide — if you have more, split across slides
- **Max 8 words per bullet** — bullets are signposts, not sentences
- **The 3-second rule** — if the audience can't grasp the point in 3 seconds, simplify
- **One idea per slide** — every slide should have a single clear purpose
- **Slides are visual, notes are verbal** — put the elaboration, data, and stories in speaker notes, not on the slide

### Slides + Notes: The Division of Labor

Slides and speaker notes serve different purposes. Getting this split right is the single biggest factor in presentation quality.

| On the slide | In the speaker notes |
|-------------|---------------------|
| Key takeaway (short phrase or stat) | Why it matters, context, evidence |
| Diagram or visual | How to walk through it, what to point out |
| 3-5 bullet signposts | The full explanation for each point |
| A provocative question | The answer, and how to facilitate discussion |
| Before/after comparison | The story of what changed and why |

**Anti-patterns to avoid:**
- Notes that restate the slide: *Slide says "40% faster", notes say "It is 40% faster"* — useless
- Notes that say "Talk about X" — too vague to be helpful under pressure
- Slides that contain the full explanation — the audience reads ahead and stops listening
- No notes at all on content slides — the presenter wings it and varies in quality

### Writing Good Speaker Notes

Good notes give the presenter a confident script without making them read verbatim. Structure each slide's notes with:

1. **Opening hook** (1 sentence) — How to introduce this slide. A question, a surprising fact, or a transition from the previous slide.
2. **Key points** (2-4 sentences) — The substance. Data, examples, or stories that bring the slide's visual to life.
3. **Transition** (1 sentence) — How to bridge to the next slide. Creates flow instead of abrupt jumps.

Example for a slide titled "Architecture Overview" showing a diagram:

```
Notice the three layers here — this wasn't our first design.
We originally had a monolith, but latency spiked at 200ms under load.
This service mesh dropped p99 latency to 45ms in the customer pilot.
The key insight: the caching layer (highlighted in green) handles 80% of reads without hitting the database.
Next, let's look at how this performs under real production traffic.
```

**When to skip notes:**
- **Title slides** — the presenter knows who they are and what the talk is about
- **Thank you / closing slides** — these are visual endpoints, not content
- **Section divider slides** — usually a single phrase; the transition is self-evident
- **Large statement slides** — *sometimes* need notes if the statement needs context, but often the statement speaks for itself

### Layout Ideas

Every slide should have a visual element — not just text.

- **Two-column**: text on one side, image/chart on the other
- **Icon grid**: icon in colored circle + bold header + description
- **Large stat callout**: big number (48-72pt) with small label below
- **Half-bleed image**: full-width image on one side with content overlay
- **Timeline/process**: numbered steps with connecting arrows
- **Comparison columns**: side-by-side before/after or pros/cons

**Visual engagement**: Add at least one non-text element per content slide (shape, line, accent bar, icon) to avoid wall-of-text syndrome. Even a simple accent bar or divider line adds visual interest.

### Typography

- Use one font for headings (with personality) and one for body (clean/readable)
- Common safe pairings: Calibri headings + Calibri body, or Segoe UI + Segoe UI
- Don't go below 18pt for any text that needs to be readable in a meeting
