# RVL Touying Theme

A reusable Touying theme for RVL group meeting slides with PDF and PowerPoint export.

## Package use

Use the published package in an existing project:

```typ
#import "@preview/rvl-group-meeting:1.0.0": *
```

Start a new project from the template package:

```bash
typst init @preview/rvl-group-meeting:1.0.0
```

## Prerequisites

- `typst` CLI
  Tested in this repo with `typst 0.14.0`
- `touying` CLI from [touying-exporter](https://github.com/touying-typ/touying-exporter)
- A working Typst package setup so `@preview/touying:0.6.1` can be resolved during compile

## Quick start

Create a new deck:

```bash
make new DATE=2026-05-11
```

Then edit `config-info(...)` in `examples/2026-05-11/main.typ` and write slides.

- `= Section` is a logical section marker only.
- In the starter template, each `== Slide Title` becomes a slide automatically.
- For larger or more stable decks, prefer explicit `#rvl-slide(...)` and `#rvl-outline-slide(...)`.

Build PDF:

```bash
make pdf IN=examples/2026-05-11/main.typ
```

Build PowerPoint:

```bash
make pptx IN=examples/2026-05-11/main.typ
```

## Reference

### Cover fields

`config-info(...)` supports separate cover fields for:

- `presenter`: the speaker shown on the cover
- `paper_authors`: optional paper author list
- `paper_venue`: optional source or venue such as `ICRA 2026` or `CVPR 2025`

### Date

The theme expects a date and renders it as `Jan 9, 2026`.

- `date: rvl-date("YYYY-MM-DD")`

### Logo

- `./rvl_template/assets/logo.png` is placed at the top-right.
- To replace the logo, overwrite that file.

### Repository layout

```text
.
├── typst.toml
├── lib.typ
├── examples/
│   └── YYYY-MM-DD/
│       ├── main.typ
│       ├── paper.pdf
│       └── figs/
├── Makefile
└── rvl_template/
    ├── assets/
    │   └── logo.png
    ├── main.typ
    └── rvl_theme.typ
├── thumbnail.png
├── skills/
│   └── rvl-group-meeting-typst/
│       └── SKILL.md
```

- `typst.toml` and `lib.typ` define the Typst package entrypoint and template metadata.
- `rvl_template/main.typ` is the starter template used by `make new`.
- `examples/` stores dated slide decks and their supporting files.
- `skills/` stores repo-local workflow guidance for slide-authoring agents.
