# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Topso'z is an offline Uzbek-English-Russian dictionary Flutter app (Android only). It aggregates 10 open-source dictionary sources into a pre-built SQLite database with FTS5 full-text search, supporting both Latin and Cyrillic Uzbek scripts.

**SDK:** Dart ^3.10.7 | **Key deps:** sqflite + sqflite_common_ffi + sqlite3_flutter_libs (FTS5 support), flutter_riverpod, go_router, google_fonts, share_plus, shared_preferences

## Commands

```bash
# Flutter
flutter analyze              # Lint check (must pass with 0 issues before any PR)
dart format .                # Format code (default settings) — required before PR
flutter pub get              # Install dependencies
flutter build apk            # Build Android APK
flutter run                  # Run on connected device/emulator

# Database rebuild (Python 3, run from project root) — three stages: download → build → enrich
pip install -r tools/requirements.txt
python tools/download_sources.py     # Fetch 14 sources (10 main + 4 enrichment) to raw_data/ (~419 MB)
python tools/build_database.py       # Parse 10 main sources → saved_database/topsoz.db
python tools/enrich_database.py      # Post-process: WordNet/Tatoeba/OpenRussian + FTS5 rebuild
python tools/test_database.py        # (optional) Validate DB integrity — 11 test suites

# After rebuilding the database, copy to assets:
cp saved_database/topsoz.db assets/db/topsoz.db
```

**Note (`flutter test` is broken in this checkout):** The local folder name contains an apostrophe (`Topso'z`), which **breaks `flutter test`** — Flutter generates a test listener that embeds the path unescaped, producing Dart parse errors (`'z' is already declared`). Rename the folder to `Topsoz` (no apostrophe) to run tests. The cloned git repo is `topsoz-app`, so this only affects this local path; `flutter analyze` and `dart format` are unaffected. Tests live in `test/`: `widget_test.dart` (transliterator), `word_model_test.dart` (`stripHtml`), `word_repository_test.dart` (search scoring — fixture + real-DB suites).

## Architecture

**App launch flow:** `main.dart` (FFI init + AdService init + SharedPreferences overrides) → `app.dart` (MaterialApp.router) → SplashScreen → OnboardingScreen (one-time) → GoRouter

**SQLite init:** Uses `sqflite_common_ffi` + `sqlite3_flutter_libs` (not default sqflite) to enable FTS5 on Android. `databaseFactory = databaseFactoryFfi` is set in `main()`.

**DB versioning & migration:** `DatabaseHelper` tracks `_databaseVersion = 2` and `_bundledDatabaseVersion = '2.0.1'` (the bundled version is read from the `meta` table, `key='version'`; keep it in sync with `DB_VERSION` in `tools/search_index.py`). First launch copies the bundled DB to the app documents dir. On a version mismatch it **preserves user data**: exports favorites + history (`_exportUserData`), deletes the old DB, copies the new bundled one, then restores the user data (`_restoreUserData`). So shipping a new dictionary DB never wipes favorites/history.

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

UI state: searchInputProvider (raw text, instant UI feedback) + searchQueryProvider (debounced value that drives the search) — two StateProvider<String>s working together; targetLanguageProvider (StateProvider<TargetLanguage>)
splashCompleteProvider (StateProvider<bool>) — in app.dart
```

**State mutation pattern:** After mutations (toggle favorite, add history), call `ref.invalidate()` on dependent providers to refresh UI. Search input uses a `Debouncer` (300ms) before updating `searchQueryProvider`.

### Navigation (GoRouter)

ShellRoute with bottom tabs (`_shellNavigatorKey`): `/search`, `/favorites`, `/history`, `/settings`
Word detail uses parent navigator (`_rootNavigatorKey`): `/word/:id` — overlays on top of tabs.

### Data Flow
- Pre-built SQLite database is bundled in `assets/db/topsoz.db`
- On first launch, `DatabaseHelper` (singleton) copies it to app documents directory via `rootBundle.load()`
- Search uses the `words_fts` FTS5 virtual table — **regular (content stored directly), not external-content**; tokenizer `unicode61 remove_diacritics 2 tokenchars ''''` with `prefix='2 3 4'` (2–4 char prefix index). It has 6 columns: `word`, `word_cyrillic`, `word_folded` (apostrophe-stripped lemma), `definitions_en`, `definitions_ru`, `definitions_all`. Built by `rebuild_search_index()` in `tools/search_index.py` (shared by build + enrich).
- Query building (`WordRepository`): each token variant is routed to the matching FTS column by script — `word_cyrillic` for Cyrillic, `word`/`word_folded` for Latin. Single-token uses `buildHeadwordMatchQuery`; multi-token uses `buildHybridMatchQuery` (headwords + language-specific definition columns). The separate `definitions_en`/`definitions_ru` columns let language-filtered search happen *inside* FTS rather than post-filtering.
- Results are ranked by `_buildScore` (multi-factor: match-type base scores e.g. exactHeadword=1000 / definitionToken=500, source-priority boost, word-length penalty, POS presence, definition-position penalty), then capped at 50 and returned as the lightweight `SearchResult` model (avoids loading full definitions in list views).

### Key Patterns
- **Models:** Immutable with `const` constructors, `copyWith()`, `fromMap()` factory
- **Async rendering:** `AsyncValue.when(data/loading/error)` for Riverpod-watched providers; `FutureBuilder` used for history repo in search screen
- **Transliteration:** `UzbekTransliterator` handles digraphs first (sh, ch, o', g', ng, yo, yu, ya) then single chars; handles multiple quote variants (`'`, `` ` ``, U+02BC)
- **Word-detail merging:** `WordRepository.getWord()` merges the same headword across sources — groups definitions into part-of-speech buckets, dedups case-insensitively (`_mergeDefinitions`), and combines source attribution (e.g. `kaikki, vuizur`). Note `Definition.source` is populated at query time from the `words` table; it is **not** a column on the `definitions` table.

### Database Schema
- `words` (id, word, word_cyrillic, language, part_of_speech, pronunciation, etymology, source) — UNIQUE on (word, language, pos, source)
- `definitions` (word_id FK CASCADE, definition, target_language, example_source, example_target, sort_order)
- `favorites` (word_id FK UNIQUE, created_at)
- `search_history` (query, word_id, searched_at) — auto-pruned to 100 entries
- `words_fts` — FTS5 virtual table (regular, **not** external-content): `word`, `word_cyrillic`, `word_folded`, `definitions_en`, `definitions_ru`, `definitions_all` — see Data Flow / `tools/search_index.py`
- `meta` — key/value table; `key='version'` holds the bundled DB version that drives migration
- Indexes: `idx_words_lang`, `idx_words_word` (COLLATE NOCASE), `idx_words_cyrillic`, `idx_defs_word`, `idx_fav_created`, `idx_hist_searched`

### Ads & Monetization (AdService)
`lib/core/services/ad_service.dart` — singleton (`AdService.instance`) managing AdMob banner, interstitial, rewarded, and native ads. **Used directly in widgets, NOT via Riverpod providers.** AdMob IDs are hardcoded in the service.

**Premium system:** Watching the 3rd rewarded video (daily cap `maxDailyRewarded = 3`) calls `_activatePremium()`, which stamps `premium_activated_at` (epoch ms). Premium then lasts **24 h from that timestamp** (`_premiumDuration = Duration(hours: 24)`) — it does **not** reset at midnight. The daily reset applies only to the rewarded *counter*, tracked by `rewarded_count` + `rewarded_date` (`YYYY-MM-DD`), which resets when the date changes. Always check `await AdService.instance.isPremiumActive()` before showing ads.

**Interstitials:** `showInterstitialIfReady()` shows an interstitial every 3rd app open, counted via `app_open_count` (SharedPreferences); it returns early (no-op) when premium is active. Ads load lazily — only `MobileAds.initialize()` runs at startup; `loadInterstitialAd()` / `loadRewardedAd()` must be called explicitly from screens.

Widget wrappers: `BannerAdWidget`, `NativeAdWidget` (in `lib/core/widgets/`) self-hide when premium is active. Interstitial/rewarded are triggered imperatively from screens.

### Data Pipeline (tools/)
Three-stage flow: **download → build → enrich** (then copy to `assets/db/`). The full rebuild sequence is in the Commands section.
- `download_sources.py` fetches **14 items** (git clone + HTTP) into `raw_data/`: 10 main dictionary sources + 4 enrichment sources (Tatoeba EN/RU sentence pairs, OpenRussian, NLTK WordNet). Some need bz2/tar/zip extraction. Raw data is ~419 MB and not committed.
- `build_database.py` runs the 10 parsers in `tools/parsers/` (each outputs the common dict `{word, language, pos, definitions[], target_language, pronunciation, etymology, examples[], source}`), merges + dedups via the `UNIQUE(word, language, part_of_speech, source)` constraint (same word allowed across sources), generates Cyrillic variants via `transliterate.py`, builds the FTS5 index via `rebuild_search_index()` (`search_index.py`), and runs VACUUM+ANALYZE.
- `enrich_database.py` runs **after** build and is part of the standard rebuild: 6 steps — English WordNet synset defs, Kaikki re-match for words lacking defs, Tatoeba example sentences, OpenRussian RU translations bridged through English, Kodchi Cyrillic cleanup, then step 6 calls `db_postprocess.canonicalize_headwords()` + `prune_definitionless_words()` — then rebuilds FTS5 again.
- `db_postprocess.py` (light-weight: only depends on `transliterate` + `sqlite3`, so it can post-process a DB without the heavy parser deps): `canonicalize_headwords()` makes the Latin `word` column canonical — transliterates Cyrillic text that wrongly lives in `word` over to Latin (moving Cyrillic to `word_cyrillic`), collapses extra/edge whitespace in multi-word headwords, drops junk that transliterates to empty (lone `ь`/`ъ`), and merges any `UNIQUE(word,language,pos,source)` collisions (moving definitions, deduping). This prevents duplicate search results (`oltin` vs `олтин`, `azob bermoq` vs `azob  bermoq`) and keeps the SQL/Dart headword normalization in parity so `getWord` sibling-merge works. It is **idempotent**. `prune_definitionless_words()` deletes words with zero definitions (the app can never surface them — they're dropped from results, can't be word-of-day, and have no nav path).
- `test_database.py` validates the result (11 suites: schema health, coverage, translation quality, FTS, edge cases, relevance).

## UI Design

Quari Translate (Dribbble) inspired — soft pastel colors in light theme, large rounded corners (20-28px), pill-shaped buttons. Colors defined in `lib/core/theme/app_colors.dart`:
- **Light theme:** primary `#9685FF` (purple), secondary `#FF865E` (coral), background `#A2D2FF` (light blue), surface `#FEF9EF` (cream)
- **Dark theme:** `darkBackground #121220`, `darkSurface #1E1E32`, `darkSurfaceLight #2A2A42`, purple/coral accents preserved

Theme mode is user-toggleable via `themeModeProvider` (persisted in SharedPreferences). Font scale is also user-adjustable via `fontScaleProvider`. Font: Rubik (Google Fonts). All UI labels are in Uzbek (Latin script).

## Language

All UI strings, comments, and user-facing text should be in Uzbek. Technical terms and code identifiers remain in English.
