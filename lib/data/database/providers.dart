import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/search_result.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/history_repository.dart';

/// SharedPreferences provayderidan mavzu rejimini boshqarish uchun notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  ThemeModeNotifier(this._prefs)
    : super(_themeModeFromString(_prefs.getString(_key)));

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }

  /// Mavzu rejimini o'zgartirish va saqlash
  void setThemeMode(ThemeMode mode) {
    state = mode;
    _prefs.setString(_key, _themeModeToString(mode));
  }

  /// Yorug' va qorong'i rejim o'rtasida almashtirish
  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// SharedPreferences provayderidan matn o'lchami koeffitsiyentini boshqarish uchun notifier
class FontScaleNotifier extends StateNotifier<double> {
  final SharedPreferences _prefs;
  static const _key = 'font_scale';

  FontScaleNotifier(this._prefs) : super(_prefs.getDouble(_key) ?? 1.0);

  /// Matn o'lchami koeffitsiyentini o'zgartirish va saqlash (0.8 dan 1.4 gacha)
  void setFontScale(double scale) {
    state = scale.clamp(0.8, 1.4);
    _prefs.setDouble(_key, state);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

/// Ilova mavzusi rejimi (yorug' yoki qorong'i) — SharedPreferences orqali saqlanadi
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  // SharedPreferences sinxron tarzda olinishi kerak — provider zanjirida
  // sharedPreferencesProvider allaqachon yuklangan bo'lishi lozim
  throw UnimplementedError(
    'themeModeProvider faqat overrideWithValue bilan ishlatilishi kerak',
  );
});

/// Matn o'lchami koeffitsiyenti (0.8 dan 1.4 gacha) — SharedPreferences orqali saqlanadi
final fontScaleProvider = StateNotifierProvider<FontScaleNotifier, double>((
  ref,
) {
  throw UnimplementedError(
    'fontScaleProvider faqat overrideWithValue bilan ishlatilishi kerak',
  );
});

/// SharedPreferences yuklangandan keyin themeModeProvider va fontScaleProvider
/// uchun override yaratish yordamchisi
Future<List<Override>> createPersistedProviderOverrides() async {
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWith((_) => prefs),
    themeModeProvider.overrideWith((_) => ThemeModeNotifier(prefs)),
    fontScaleProvider.overrideWith((_) => FontScaleNotifier(prefs)),
  ];
}

final databaseProvider = FutureProvider<Database>((ref) async {
  try {
    return await DatabaseHelper.instance.database;
  } catch (e) {
    throw Exception("Ma'lumotlar bazasini ochishda xatolik: $e");
  }
});

final wordRepositoryProvider = FutureProvider<WordRepository>((ref) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    return WordRepository(db);
  } catch (e) {
    throw Exception("So'zlar omborini yaratishda xatolik: $e");
  }
});

final favoritesRepositoryProvider = FutureProvider<FavoritesRepository>((
  ref,
) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    return FavoritesRepository(db);
  } catch (e) {
    throw Exception("Sevimlilar omborini yaratishda xatolik: $e");
  }
});

final historyRepositoryProvider = FutureProvider<HistoryRepository>((
  ref,
) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    return HistoryRepository(db);
  } catch (e) {
    throw Exception("Tarix omborini yaratishda xatolik: $e");
  }
});

enum TargetLanguage { all, en, ru }

final searchInputProvider = StateProvider<String>((ref) => '');
final searchQueryProvider = StateProvider<String>((ref) => '');
final targetLanguageProvider = StateProvider<TargetLanguage>(
  (ref) => TargetLanguage.all,
);

final searchResultsProvider = FutureProvider.autoDispose<List<SearchResult>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = await ref.watch(wordRepositoryProvider.future);
  final lang = ref.watch(targetLanguageProvider);
  final langFilter = lang == TargetLanguage.all ? null : lang.name;
  return repo.search(query, targetLanguage: langFilter);
});

final recentSearchesProvider = FutureProvider.autoDispose<List<HistoryEntry>>((
  ref,
) async {
  final repo = await ref.watch(historyRepositoryProvider.future);
  return repo.getRecent(limit: 8);
});

final wordOfDayProvider = FutureProvider.autoDispose<Word?>((ref) async {
  final repo = await ref.watch(wordRepositoryProvider.future);
  return repo.getRandomWord();
});

final historyListProvider = FutureProvider.autoDispose<List<HistoryEntry>>((
  ref,
) async {
  final repo = await ref.watch(historyRepositoryProvider.future);
  return repo.getRecent(limit: 50);
});

final favoritesListProvider = FutureProvider.autoDispose<List<Word>>((
  ref,
) async {
  final repo = await ref.watch(favoritesRepositoryProvider.future);
  return repo.getAll();
});

final wordDetailProvider = FutureProvider.autoDispose.family<Word?, int>((
  ref,
  id,
) async {
  final repo = await ref.watch(wordRepositoryProvider.future);
  return repo.getWord(id);
});

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('onboarding_complete') ?? false;
});

/// Ma'lumotlar bazasidagi so'zlar soni
final wordCountProvider = FutureProvider<int>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
  return result.first['count'] as int;
});

/// Ma'lumotlar bazasidagi ta'riflar soni
final definitionCountProvider = FutureProvider<int>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM definitions');
  return result.first['count'] as int;
});
