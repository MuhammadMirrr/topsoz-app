# Changelog

All notable changes to **Topso'z** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] — 2026-06-14

### Added
- Multi-language README (EN/UZ/RU/AR).
- MIT License, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.

### Fixed
- Word detail now merges definitions across sources that stored the headword with different apostrophe glyphs (e.g. `ko'p` previously showed 1 of 15 definitions).
- 3-letter words (e.g. `car`, `cat`, `sun`, `dog`) are now found via their English definitions.
- Cyrillic text wrongly stored in the Latin headword column is transliterated to Latin, eliminating duplicate search results (`oltin` vs `олтин`).
- Multi-word headwords with extra internal whitespace now merge correctly in the word detail view.
- `stripHtml` now trims leading/trailing whitespace on plain text.

### Changed
- Removed ~22,300 definition-less placeholder entries; bundled DB shrunk (~84 MB → ~74 MB).
- Bundled dictionary DB version 2.0.0 → 2.0.1. Existing installs migrate automatically, preserving favorites/history (including kodchi words whose script changed Cyrillic → Latin).

## [1.0.0] — 2026-04-21

### Added
- Offline Uzbek–English–Russian dictionary with ~71,000 words and ~197,000 definitions.
- Full-text search (FTS5) with Uzbek Latin/Cyrillic transliteration support.
- Search modes: **Hammasi** (all), **Inglizcha** (English), **Ruscha** (Russian).
- Dark theme, font size control, 3 UI languages (UZ/EN/RU).
- Favorites and search history, persisted locally.
- Word detail screen with grouped definitions per language.
- Onboarding flow for first-time users.
- AdMob integration (banner, native, interstitial, rewarded).
- Premium reward system: 3 rewarded videos = 24 h ad-free.
- Python data pipeline (`tools/`) aggregating 10 open-source dictionary sources.

### Fixed
- Russian search returned empty for valid queries — filter relaxed and fallback chain added.
- Auto-transliteration: Uzbek Cyrillic typed in Russian mode is converted to Latin and retried.
- Raw HTML tags shown in definitions — sanitized at build time and at runtime.
- Duplicate entries from different sources now merged into a single list with source labels.

[Unreleased]: https://github.com/MuhammadMirrr/topsoz-app/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/MuhammadMirrr/topsoz-app/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/MuhammadMirrr/topsoz-app/releases/tag/v1.0.0
