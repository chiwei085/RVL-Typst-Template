# RVL Touying Theme

A reusable Touying theme for RVL group meeting slides.

## Quick start

For example, the project structure be like:

```bash
.
├── 2026-02-03/
│   └── main.typ            # Your slides
├── Makefile                # Build helpers (pptx/pdf)
└── rvl_template/
    ├── assets/
    │   └── logo.png
    └── rvl_theme.typ
```

In your slide file, import the theme:

```typ
#import "../rvl_template/rvl_theme.typ": *
```

Build a PowerPoint file (run from the repo root):

```bash
make pptx IN=[path to the typst file]
```

> [!IMPORTANT] 
> Make sure you have Typst and Touying Exporter installed.  
> For setup details, see [touying-exporter](https://github.com/touying-typ/touying-exporter)

## Date formatting

The theme expects a date and renders it as Jan 9, 2026.

- `date: rvl-date("YYYY-MM-DD")` 
- or `date: datetime(year: 2026, month: 1, day: 9)`

## Section headings (`= ...`)

`= Section` is treated as a logical marker only.  
Each slide is created by `== Slide Title`.

## Assets

- `./assets/logo.png` is placed at the top-right.  
If you want to replace it, just overwrite that file.