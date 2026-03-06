---
name: pptx
description: "Use this skill any time a PowerPoint file (.pptx or .potx) is involved — creating presentations, reading content, editing slides, or working with templates. Trigger when the user mentions slides, decks, presentations, PowerPoint, or references a .pptx/.potx file. Requires Windows with Microsoft PowerPoint installed."
---

# PowerPoint Skill (COM Automation)

Uses PowerPoint COM automation for native-quality rendering, template support, and zero external dependencies.

## Quick Reference

| Task | Guide |
|------|-------|
| List available layouts (compact) | Run `scripts/Get-PresentationInfo.ps1 -LayoutsOnly` |
| Analyze specific slides | Run `scripts/Get-PresentationInfo.ps1 -SlideRange "25,41-45"` |
| Full analysis of a presentation | Run `scripts/Get-PresentationInfo.ps1` |
| Visual preview of slides | Run `scripts/Export-SlideThumbnails.ps1` |
| Accessibility audit | Run `scripts/Test-Accessibility.ps1` |
| Design quality audit | Run `scripts/Test-DesignQuality.ps1` |
| Accessibility patterns | Read [accessibility.md](accessibility.md) |
| Create from a template (.potx/.pptx) | Read [template-workflow.md](template-workflow.md) |
| Create from scratch | Read [from-scratch.md](from-scratch.md) |
| COM API reference | Read [com-reference.md](com-reference.md) |

---

## Reading Content

```powershell
# Quick layout inventory (compact, deduplicated)
.\scripts\Get-PresentationInfo.ps1 -Path "presentation.pptx" -LayoutsOnly

# Shape details for specific slides only
.\scripts\Get-PresentationInfo.ps1 -Path "presentation.pptx" -SlideRange "1,3,5-8"

# Full structured report: dimensions, layouts, per-slide shapes and text
.\scripts\Get-PresentationInfo.ps1 -Path "presentation.pptx"

# Visual thumbnail grid (outputs to thumbs/ next to the input file)
.\scripts\Export-SlideThumbnails.ps1 -Path "output/My-Deck/My-Deck.pptx"
```

---

## Output Location

All generated files go under `output/` in the workspace root, grouped by presentation:

```
output/
  My-Deck/
    My-Deck.pptx             # The presentation
    thumbs/                   # Slide thumbnails and grid image
  Another-Deck/
    Another-Deck.pptx
    thumbs/
```

`Export-SlideThumbnails.ps1` defaults to a `thumbs/` subdirectory next to the input file, so grouping happens automatically.

---

## Templates Directory

Place `.potx` and `.pptx` templates in the [`templates/`](templates/) directory. Scripts resolve template names from this directory automatically — users can pass just a filename instead of a full path.

---

## Creating from Template

**Read [template-workflow.md](template-workflow.md) for full details.**

1. Analyze template with `Get-PresentationInfo.ps1 -LayoutsOnly` and `Export-SlideThumbnails.ps1`
2. Plan slides: map content to layouts, plan speaker notes alongside slide content
3. Create new presentation with `New-PresentationFromTemplate.ps1` (auto-emits shape names)
4. Edit content and speaker notes via inline COM PowerShell using the emitted shape names — set alt text on images during this step
5. Visual QA with `Export-SlideThumbnails.ps1`
6. Design quality check with `Test-DesignQuality.ps1`
7. Accessibility check with `Test-Accessibility.ps1`

---

## Creating from Scratch

**Read [from-scratch.md](from-scratch.md) for full details.**

Use when no template is available. Build slides programmatically via COM automation.

1. Create a new blank presentation via COM
2. Add slides with desired layouts
3. Populate content, speaker notes, and alt text during creation
4. Visual QA with `Export-SlideThumbnails.ps1`
5. Accessibility check with `Test-Accessibility.ps1`

---

## Requirements

- **Windows** with **Microsoft PowerPoint** installed
- **PowerShell 5.1+** (Windows PowerShell) or **PowerShell 7+** (pwsh)
