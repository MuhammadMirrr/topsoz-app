# Contributing to Topso'z

Thanks for your interest in improving Topso'z! This document explains how to propose changes.

## Getting started

1. Fork the repository and clone your fork.
2. Install Flutter (Dart SDK `^3.10.7`) and Python 3 (for dictionary build scripts).
3. Run `flutter pub get` to install dependencies.
4. Verify the project builds:

   ```bash
   flutter analyze   # must pass with 0 issues
   flutter build apk
   ```

## Branching & commits

- Work on a feature branch off `main`: `feat/short-description` or `fix/short-description`.
- Keep commits focused. Use clear messages (imperative mood): `Fix: duplicate results in Russian search`.
- Reference issues when relevant: `Fix #42: …`.

## Code style

- Follow the existing style in `lib/` (Riverpod + go_router + feature-based folders).
- Run `flutter analyze` before every commit — the lint must stay clean.
- UI strings are in Uzbek (Latin script). Code identifiers are in English.

## Dictionary data

- Source parsers live in `tools/parsers/`. Each parser outputs the common dict format documented in [CLAUDE.md](CLAUDE.md).
- Raw source dumps (`raw_data/`) and generated DB (`saved_database/`) are ignored — do not commit them.
- After regenerating, copy `saved_database/topsoz.db` → `assets/db/topsoz.db`.

## Pull requests

- Describe *what* changed and *why*.
- Include screenshots/GIFs for UI changes.
- Confirm `flutter analyze` is clean and the app still builds.
- One logical change per PR — split large work.

## Reporting bugs

Open a GitHub Issue with:
- Device model + Android version
- Steps to reproduce
- Expected vs. actual behaviour
- Logs if available (`flutter logs`)

## Security

Do **not** open public issues for security problems. See [SECURITY.md](SECURITY.md).

## Code of Conduct

By participating, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).
