# Changelog

All notable changes to this template are documented in this file.

## v0.1.0 - 2026-05-03

### Added

- Added `make new DATE=YYYY-MM-DD` to scaffold a new deck under `examples/`.
- Added repo-local slide authoring guidance in `skills/rvl-group-meeting-typst/SKILL.md`.
- Added Tinymist hover docs for the public theme API in `rvl_template/rvl_theme.typ`.
- Added `typst.toml`, `lib.typ`, `template/`, and template metadata so the repo can be published as a Typst package.

### Changed

- Reorganized example decks under `examples/YYYY-MM-DD/`.
- Updated README to separate quick start from reference material.
- Clarified the two supported slide authoring modes:
  automatic heading-driven slides in the starter template, and explicit `#rvl-slide(...)` / `#rvl-outline-slide(...)` for larger decks.
- Centralized theme colors and cover layout constants in `rvl_template/rvl_theme.typ`.
- Renamed the package to `steady-rvl-slides` and aligned versioning to `0.1.0`.
- Moved the theme implementation to `src/rvl_theme.typ` and removed duplicate template-local theme files.

### Removed

- Removed legacy root-level example files that were replaced by the `examples/` layout.
