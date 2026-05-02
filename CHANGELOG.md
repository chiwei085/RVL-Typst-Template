# Changelog

All notable changes to this template are documented in this file.

## v1.0 - 2026-05-02

### Added

- Added `make new DATE=YYYY-MM-DD` to scaffold a new deck under `examples/`.
- Added repo-local slide authoring guidance in `skills/rvl-group-meeting-typst/SKILL.md`.
- Added Tinymist hover docs for the public theme API in `rvl_template/rvl_theme.typ`.

### Changed

- Reorganized example decks under `examples/YYYY-MM-DD/`.
- Updated README to separate quick start from reference material.
- Clarified the two supported slide authoring modes:
  automatic heading-driven slides in the starter template, and explicit `#rvl-slide(...)` / `#rvl-outline-slide(...)` for larger decks.
- Centralized theme colors and cover layout constants in `rvl_template/rvl_theme.typ`.

### Removed

- Removed legacy root-level example files that were replaced by the `examples/` layout.
