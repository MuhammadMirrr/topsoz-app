# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

Topso'z is an offline Uzbek-English-Russian dictionary Flutter app (Android only). It aggregates 10 open-source dictionary sources into a pre-built SQLite database with FTS5 full-text search, supporting both Latin and Cyrillic Uzbek scripts.

**SDK:** Dart ^3.10.7 | **Key deps:** sqflite + sqflite_common_ffi + sqlite3_flutter_libs (FTS5 support), flutter_riverpod, go_router, google_fonts, share_plus, shared_preferences

## Commands

```bash
# Flutter
flutter analyze              # Lint check (must pass with 0 issues)
flutter pub get              # Install dependencies
flutter build apk            # Build Android APK
flutter run                  # Run on connected device/emulator

# Database rebuild (Python 3, run from project root)
pip install -r tools/requirements.txt
python tools/download_sources.py     # Download all dictionary sources to raw_data/
python tools/build_database.py       # Parse sources and build saved_database/topsoz.db

# After rebuilding the database, copy to assets:
cp saved_database/topsoz.db assets/db/topsoz.db
```

**Note:** The folder name contains an apostrophe (`Topso'z`) which breaks `flutter test`. Rename to `Topsoz` if tests are needed.

## Architecture

**App launch flow:** `main.dart` (FFI init + SharedPreferences overrides) → `app.dart` (MaterialApp.router) → SplashScreen → OnboardingScreen (one-time) → GoRouter

**SQLite init:** Uses `sqflite_common_ffi` + `sqlite3_flutter_libs` (not default sqflite) to enable FTS5 on Android. `databaseFactory = databaseFactoryFfi` is set in `main()`.

**Persisted settings:** `themeModeProvider` and `fontScaleProvider` use `StateNotifierProvider` with `overrideWithValue` pattern — they throw `UnimplementedError` if not overridden. `createPersistedProviderOverrides()` in `providers.dart` creates the overrides from SharedPreferences at startup.

### Riverpod Provider Chain

```
createPersistedProviderOverrides() → themeModeProvider, fontScaleProvider (overridden at startup)

databaseProvider (FutureProvider<Database>)  ← DatabaseHelper.instance singleton
  ├── wordRepositoryProvider (FutureProvider)
  │     ├── searchResultsProvider (autoDispose) ← watches searchQueryProvider + targetLanguageProvider
  │     ├── wordOfDayProvider (autoDispose) ← getRandomWord()
  │     └── wordDetailProvider (autoDispose.family<Word?, int>)
  ├── favoritesRepositoryProvider (FutureProvider)
  │     └── favoritesListProvider (autoDispose)
  ├── historyRepositoryProvider (FutureProvider)
  │     ├── recentSearchesProvider (autoDispose, limit: 8)
  │     └── historyListProvider (autoDispose, limit: 50)
  ├── wordCountProvider, definitionCountProvider (stats)
  └── onboardingCompleteProvider ← SharedPreferences

UI state: searchQueryProvider (StateProvider<String>), targetLanguageProvider (StateProvider<TargetLanguage>)
splashCompleteProvider (StateProvider<bool>) — in app.dart
```

**State mutation pattern:** After mutations (toggle favorite, add history), call `ref.invalidate()` on dependent providers to refresh UI. Search input uses a `Debouncer` (300ms) before updating `searchQueryProvider`.

### Navigation (GoRouter)

ShellRoute with bottom tabs (`_shellNavigatorKey`): `/search`, `/favorites`, `/history`, `/settings`
Word detail uses parent navigator (`_rootNavigatorKey`): `/word/:id` — overlays on top of tabs.

### Data Flow
- Pre-built SQLite database is bundled in `assets/db/topsoz.db`
- On first launch, `DatabaseHelper` (singleton) copies it to app documents directory via `rootBundle.load()`
- Search uses FTS5 virtual table (`words_fts`) with `unicode61 remove_diacritics 2` tokenizer and prefix matching (`query*`)
- Script detection: if query contains Cyrillic chars (U+0400–U+04FF), matches `word_cyrillic` column only; otherwise matches all FTS columns (word, word_cyrillic, definitions)
- Search results capped at 50, use lightweight `SearchResult` model (avoids loading full definitions in list views)

### Key Patterns
- **Models:** Immutable with `const` constructors, `copyWith()`, `fromMap()` factory
- **Async rendering:** `AsyncValue.when(data/loading/error)` for Riverpod-watched providers; `FutureBuilder` used for history repo in search screen
- **Transliteration:** `UzbekTransliterator` handles digraphs first (sh, ch, o', g', ng, yo, yu, ya) then single chars; handles multiple quote variants (`'`, `` ` ``, U+02BC)

### Database Schema
- `words` (id, word, word_cyrillic, language, part_of_speech, pronunciation, etymology, source) — UNIQUE on (word, language, pos, source)
- `definitions` (word_id FK CASCADE, definition, target_language, example_source, example_target, sort_order)
- `favorites` (word_id FK UNIQUE, created_at)
- `search_history` (query, word_id, searched_at) — auto-pruned to 100 entries
- `words_fts` — FTS5 external content table (word, word_cyrillic, concatenated definitions)
- Indexes: `idx_words_lang`, `idx_words_word` (COLLATE NOCASE), `idx_words_cyrillic`, `idx_defs_word`, `idx_fav_created`, `idx_hist_searched`

### Data Pipeline (tools/)
`download_sources.py` fetches 10 sources (git clone + HTTP) into `raw_data/`. Each parser in `tools/parsers/` outputs a common dict format: `{word, language, pos, definitions[], target_language, pronunciation, etymology, examples[], source}`. `build_database.py` merges all, deduplicates via UNIQUE constraints (same word allowed across different sources), generates Cyrillic variants via `transliterate.py`, builds FTS5 index, runs VACUUM+ANALYZE. Additional scripts: `enrich_database.py` (post-processing), `test_database.py` (validation queries).

## UI Design

Quari Translate (Dribbble) inspired — soft pastel colors, large rounded corners (20-28px), pill-shaped buttons. Colors: primary `#9685FF` (purple), secondary `#FF865E` (coral), background `#A2D2FF` (light blue), surface `#FEF9EF` (cream). Font: Rubik (Google Fonts). All UI labels are in Uzbek (Latin script).

## Language

All UI strings, comments, and user-facing text should be in Uzbek. Technical terms and code identifiers remain in English.
