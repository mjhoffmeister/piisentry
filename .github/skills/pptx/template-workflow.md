# Creating from a Template

## Output Location

All generated files go under an `output/` directory in the workspace root, grouped per presentation:

```
output/
  My-Deck/
    My-Deck.pptx             # The presentation
    thumbs/                   # Slide thumbnails and grid image
      thumbnails.jpg
      slide_1.jpg
      slide_2.jpg
      ...
  Another-Deck/
    Another-Deck.pptx
    thumbs/
      ...
```

Use this convention consistently. The `Export-SlideThumbnails.ps1` script defaults to a `thumbs/` subdirectory next to the input file when `-OutputDir` is omitted.

## Template Location

Place templates in the `templates/` directory. Scripts resolve filenames from there automatically:

```powershell
# These are equivalent if "corporate.potx" exists in templates/
.\scripts\New-PresentationFromTemplate.ps1 -TemplatePath "corporate.potx" -OutputPath "output/My-Deck/My-Deck.pptx"
.\scripts\New-PresentationFromTemplate.ps1 -TemplatePath "templates\corporate.potx" -OutputPath "output/My-Deck/My-Deck.pptx"
```

---

## Workflow

### 1. Analyze the Template

```powershell
# Quick layout inventory — one line per unique layout
.\scripts\Get-PresentationInfo.ps1 -Path "template.potx" -LayoutsOnly

# Full details for specific slides (after picking layouts)
.\scripts\Get-PresentationInfo.ps1 -Path "template.potx" -SlideRange "25,41-45,61"

# Get visual overview of all slides
.\scripts\Export-SlideThumbnails.ps1 -Path "template.potx" -OutputDir "output/thumbs"
```

Start with `-LayoutsOnly` to get a compact, deduplicated list of available layouts. Then use `-SlideRange` to inspect shape details for only the slides you care about.

#### Skipping Guide Slides

Templates often begin with instructional or guideline slides — usage tips, font checks, color palettes — before the actual presentation layouts start. These are typically consecutive Blank-layout slides at the beginning of the template. When picking source slides for your SlideSpec, skip past these guide slides and start from where the named layouts (e.g., Speaker Card, Section, Title and Content) begin.

#### Finding the Title/Opening Slide

Not all templates have a layout explicitly named "Title Slide" or "Title." If no layout name contains "title" (other than "Title and Content" or "Title and Subtitle," which are body slides), look for layouts whose names suggest an opening or speaker introduction — common examples include "Speaker Card," "Opening," "Cover," "Intro," or "Welcome." These typically appear as the first named layout after any guide slides and include placeholders for a presentation title, speaker name, role, or photo.

#### Understanding Template Themes

Templates often contain the same layouts repeated across multiple slide masters (themes). For example, a GitHub template may have layouts under "GitHub Default Theme_dark version", "Copilot/AI Theme_dark version", "Security Theme_dark version", and their light counterparts.

Each theme block contains similar layouts (e.g., "Title and Content", "Thank you") but with different visual styling. When selecting slides for your SlideSpec:

- Use slides from the **first theme block** unless the user requests a specific theme
- `-LayoutsOnly` shows the first occurrence of each layout name, which is the first theme
- If you need a different theme, scan the full output for the same layout name at a higher slide index

### Design Principles

Templates provide visual styling, but you still control content density and engagement. Apply these rules when planning and editing slides:

- **Content density**: Max 6 bullet points per slide, max 8 words per bullet. If you have more, split across multiple slides.
- **Visual variety**: Never use 3+ consecutive slides with the same layout. Alternate between content-heavy layouts (Title and Content) and visual-heavy layouts (Large statement, Three statements, Content and image).
- **Slide rhythm**: Follow a pattern: statement → detail → visual → statement. Use Large statement slides to create breathing room between dense content.
- **The 3-second rule**: If the audience can't grasp a slide's main point in 3 seconds, it has too much content.
- **Avoid Section slides**: Section layout slides often carry template-default text or decorative elements that look out of place when repurposed. Use a Large statement slide instead to introduce a new topic — it's cleaner and fully editable.
- **Clean inherited sections**: Templates carry slide-sorter metadata sections (e.g., "Default theme_dark mode") that group slides by theme variant. These are meaningless in output presentations. `New-PresentationFromTemplate.ps1` removes them automatically; if editing manually, delete them via `$pres.SectionProperties.Delete($i, $false)`.
- **Every slide needs a purpose**: Title (orient), Statement (transition/emphasize), Content (inform), Visual (illustrate), Summary (reinforce). If you can't name a slide's purpose, reconsider it.
- **Slides are visual, notes are verbal**: Put the key takeaway on the slide. Put the explanation, data, stories, and transitions in speaker notes. If you find yourself cramming text onto a slide, move the detail to notes and keep the slide as a visual signpost.
- **Layout fitness**: Only use layouts with image placeholders (Content and image, Three statements, Two statements, Content + Browser, etc.) when you have actual images to fill them. If you only have text content, prefer text-only layouts (Title and Content, Large statement). An empty image placeholder produces a visually broken slide.
- **Content structure → layout structure**: When content naturally divides into N parallel groups (e.g., "Two types of deployment," "Three key benefits," "Four core principles"), use a multi-column layout that matches the count, rather than flattening everything into a single bulleted slide. This preserves visual hierarchy and makes the slide scannable. Apply these rules:
  - **Identify grouped content**: If your content has N named categories, types, pillars, or steps with supporting details under each, it is grouped content — not a flat list.
  - **Match the count to a layout**: Scan the `-LayoutsOnly` output for multi-column layouts whose name or structure suggests N parallel regions (e.g., layouts with "two", "three", "2-up", "columns", "comparison" in the name, or layouts with repeated sets of placeholders). Use `-SlideRange` to confirm the placeholder structure matches your content grouping.
  - **Check for image placeholders**: Some multi-column layouts include `Picture Placeholder` shapes in each column. If you don't have images to fill them, look for an alternative multi-column layout without picture placeholders. If none exists, consider whether the content works better split across multiple single-column slides.
  - **Fall back to single-column only for truly flat lists**: Use a general content/body layout when content is a single flat list of independent points — not when points are grouped under categories.
- **Accessibility from the start**: Set alt text on images during content editing (Step 4), not as an afterthought. Mark decorative shapes immediately. See [accessibility.md](accessibility.md).

### 2. Plan Your Slides

Before creating the presentation, map your content to layouts:

1. Review the `-LayoutsOnly` output to see what layout types are available
2. For each section of your content, pick the best-fit layout
3. Build a content plan — a list of slide number → layout → title → body points
4. Build the SlideSpec JSON from your chosen source slide numbers

Example content plan:

```
Slide 1: source N (title/opening layout)    → "Presentation Title" / "Subtitle"       [no notes]
Slide 2: source N (statement layout)        → Key message                              [notes: context for why this matters]
Slide 3: source N (2-column layout)         → "Two Approaches" / Approach A vs B       [notes: detail for each]
Slide 4: source N (body/content layout)     → Flat list of independent points          [notes: stories/data behind each bullet]
Slide 5: source N (3-column layout)         → "Three Benefits" / Speed, Quality, Scale [notes: examples for each]
Slide 6: source N (closing layout)          → Closing slide                            [no notes]
```

**Layout selection for grouped content:** When content has N named categories with supporting details (e.g., "Two Approaches: Manual and Automated"), choose a multi-column layout that matches rather than a single-column body slide. Reserve body/content layouts for flat, ungrouped bullet lists. Use `-LayoutsOnly` and `-SlideRange` to identify which template layouts support multi-column content.

For layouts with `Picture Placeholder` shapes, include an `[image: ...]` annotation identifying the image source. If no image is available during planning, switch to a text-only layout instead.

Plan notes alongside content — deciding what goes on the slide vs. in notes is a design decision, not an afterthought.

**Planning checkpoint:** Review your plan for image placeholders — every slide using a layout with `Picture Placeholder` shapes must have an identified image source. If no image is available, switch to a text-only layout.

Planning upfront prevents rework from discovering mid-implementation that a layout doesn't fit the content.

### 3. Create the Presentation

```powershell
# From .potx — PowerPoint creates a new presentation based on the template
.\scripts\New-PresentationFromTemplate.ps1 -TemplatePath "template.potx" -OutputPath "output/My-Deck/My-Deck.pptx"

# From .pptx — copies and saves as new file
.\scripts\New-PresentationFromTemplate.ps1 -TemplatePath "reference.pptx" -OutputPath "output/My-Deck/My-Deck.pptx"

# With slide spec — keep/duplicate specific slides
$spec = '[{"source":1},{"source":3,"duplicate":2},{"source":5}]'
.\scripts\New-PresentationFromTemplate.ps1 -TemplatePath "template.potx" -OutputPath "output/My-Deck/My-Deck.pptx" -SlideSpec $spec
```

The script automatically prints shape names for each output slide after saving. Use this output directly to write your edit code — no need to re-analyze the output file separately.

### 4. Edit Content

Write a single COM script that edits all slides at once using the shape names from step 3.

```powershell
$existingPPT = @(Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$app = New-Object -ComObject PowerPoint.Application
$pres = $app.Presentations.Open("$(Resolve-Path output/My-Deck/My-Deck.pptx)")

try {
    # --- Edit slides ---

    # Your slide editing code here (see patterns below)

    # --- Speaker notes ---
    # Set notes on content slides (skip title/closing slides)
    $pres.Slides.Item(2).NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = @"
This statistic surprised our early customers too.
In pilot testing, teams saw this improvement within the first two weeks.
The key driver was removing the manual approval step entirely.
Transition: Let's break down the three components that make this work.
"@

    # --- Accessibility: set language on all text ---
    foreach ($slide in $pres.Slides) {
        foreach ($shape in $slide.Shapes) {
            if ($shape.HasTextFrame) {
                $shape.TextFrame.TextRange.LanguageID = 1033  # English (US)
            }
        }
    }

    $pres.Save()
    Write-Host "Saved: $($pres.FullName)"
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

> **Tip — large edits:** For presentations with many slides, save the edit code as a `.ps1` file and run it instead of pasting long inline scripts. This avoids terminal truncation and makes debugging easier. **Delete the temporary `.ps1` file after the presentation is saved successfully.**

### 5. Visual QA

```powershell
.\scripts\Export-SlideThumbnails.ps1 -Path "output/My-Deck/My-Deck.pptx"
```

Defaults to `output/My-Deck/thumbs/`. Review the grid image to verify content is correct and layouts look right.

### 6. Design Quality Check

Run the design audit to catch layout/content mismatches — empty image placeholders, excessive content density, and missing speaker notes:

```powershell
.\scripts\Test-DesignQuality.ps1 -Path "output/My-Deck/My-Deck.pptx"
```

Fix any errors (especially empty image placeholders — either add an image or switch to a text-only layout), then re-run to verify.

### 7. Accessibility Check

Run the audit with `-Fix` to auto-remediate issues (reading order, font sizes, decorative lines, language, table headers):

```powershell
.\scripts\Test-Accessibility.ps1 -Path "output/My-Deck/My-Deck.pptx" -Fix
```

The script fixes what it can and reports what remains. Remaining issues (alt text, link text, contrast) require manual fixes — use patterns from [accessibility.md](accessibility.md). After fixing, re-run without `-Fix` to verify:

```powershell
.\scripts\Test-Accessibility.ps1 -Path "output/My-Deck/My-Deck.pptx"
```

Repeat until the report shows zero errors.

---

## Content Editing Patterns

### Replace Placeholder Text

```powershell
$slide = $pres.Slides.Item(1)
foreach ($shape in $slide.Shapes) {
    if ($shape.HasTextFrame) {
        $text = $shape.TextFrame.TextRange.Text
        if ($text -match "placeholder|lorem|click to") {
            $shape.TextFrame.TextRange.Text = "Your actual content"
        }
    }
}
```

### Replace Text by Placeholder Type

```powershell
$slide = $pres.Slides.Item(1)
foreach ($shape in $slide.Shapes) {
    try {
        $phType = $shape.PlaceholderFormat.Type
        switch ($phType) {
            1  { $shape.TextFrame.TextRange.Text = "Slide Title" }         # ppPlaceholderTitle
            2  { $shape.TextFrame.TextRange.Text = "Body content here" }   # ppPlaceholderBody
            3  { $shape.TextFrame.TextRange.Text = "Center Title" }        # ppPlaceholderCenterTitle
            12 { $shape.TextFrame.TextRange.Text = "Subtitle text" }       # ppPlaceholderSubtitle
        }
    } catch {
        # Shape is not a placeholder — skip
    }
}
```

### Replace Text by Shape Name

```powershell
$slide = $pres.Slides.Item(1)
$shape = $slide.Shapes.Item("Title 1")
$shape.TextFrame.TextRange.Text = "New Title"
```

### Format Text (Bold, Size, Color, Font)

```powershell
$range = $shape.TextFrame.TextRange
$range.Text = "Important heading"
$range.Font.Bold = $true
$range.Font.Size = 28
$range.Font.Name = "Calibri"
$range.Font.Color.RGB = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb(30, 39, 97))
```

### Multi-Paragraph Content

```powershell
$tf = $shape.TextFrame.TextRange
$tf.Text = ""

# Add paragraphs
$tf.Text = "First Point`r`nSecond Point`r`nThird Point"

# Format individual paragraphs
$tf.Paragraphs(1).Font.Bold = $true
$tf.Paragraphs(2).Font.Bold = $false
```

### Bulleted Lists

```powershell
$tf = $shape.TextFrame.TextRange
$tf.Text = "Item one`r`nItem two`r`nItem three"

# Enable bullets for all paragraphs
$tf.ParagraphFormat.Bullet.Type = 1  # ppBulletUnnumbered
```

### Speaker Notes

```powershell
# Set notes — the presenter's narrative for this slide
$slide = $pres.Slides.Item(3)
$slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = @"
Open with the customer quote from the case study.
Walk through each of the three points left to right.
For point 2, mention the 40% latency reduction — this is the strongest proof point.
Transition: "Now let's see this in a live demo."
"@

# Read existing notes
$existingNotes = $slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text
```

Write notes for content slides during the same edit pass as slide content. See the [Design Principles](#design-principles) section for what makes good vs. bad notes.

### Add a New Slide from a Layout

```powershell
# Use Designs to access layouts (SlideMasters.Count returns 0 in COM interop)
$layout = $pres.Designs.Item(1).SlideMaster.CustomLayouts.Item(2)  # Pick layout by index
$newSlide = $pres.Slides.AddSlide($pres.Slides.Count + 1, $layout)

# Or use the simpler Add() with a ppSlideLayout enum value
# $newSlide = $pres.Slides.Add($pres.Slides.Count + 1, 2)  # ppLayoutText = 2
```

### Delete a Slide

```powershell
$pres.Slides.Item(3).Delete()
```

### Reorder Slides

```powershell
# Move slide 5 to position 2
$pres.Slides.Item(5).MoveTo(2)
```

### Add an Image

```powershell
$slide = $pres.Slides.Item(1)
# AddPicture(FileName, LinkToFile, SaveWithDocument, Left, Top, Width, Height)
$pic = $slide.Shapes.AddPicture(
    "$(Resolve-Path image.png)",
    $false,  # Don't link
    $true,   # Save with document
    72,      # Left (1 inch)
    144,     # Top (2 inches)
    360,     # Width (5 inches)
    216      # Height (3 inches)
)
$pic.AlternativeText = "Diagram showing the three-step onboarding workflow"
```

> **Always set alt text** on images and content shapes at creation time. You already know what the image represents — don't defer to a separate accessibility pass.

### Add a Table

```powershell
$slide = $pres.Slides.Item(1)
# AddTable(NumRows, NumColumns, Left, Top, Width, Height)
$tableShape = $slide.Shapes.AddTable(3, 4, 72, 144, 648, 216)
$table = $tableShape.Table

$table.Cell(1, 1).Shape.TextFrame.TextRange.Text = "Header 1"
$table.Cell(1, 2).Shape.TextFrame.TextRange.Text = "Header 2"
$table.Cell(2, 1).Shape.TextFrame.TextRange.Text = "Data 1"
$table.Cell(2, 2).Shape.TextFrame.TextRange.Text = "Data 2"

# Bold header row for accessibility (screen readers identify headers)
for ($col = 1; $col -le $table.Columns.Count; $col++) {
    $table.Cell(1, $col).Shape.TextFrame.TextRange.Font.Bold = $true
}
$tableShape.AlternativeText = "Comparison table with 2 data rows"
```

---

## Common Pitfalls

### Template Adaptation

When source content has fewer items than the template:
- **Remove excess shapes entirely** — don't just clear their text
- Check the thumbnail QA to catch orphaned visuals

When content is longer than the template expects:
- Text may overflow or shrink with auto-fit
- Consider splitting across multiple slides
- Set `$shape.TextFrame.AutoSize = 0` (ppAutoSizeNone) to prevent auto-shrink

### Shape Names

Shape names (e.g., "Title 1", "Content Placeholder 2") vary between templates. Always use `Get-PresentationInfo.ps1` to discover the actual names rather than guessing.

### COM Cleanup

Always wrap COM operations in try/finally and release objects. Orphaned `POWERPNT.EXE` processes will lock files.
