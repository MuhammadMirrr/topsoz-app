import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'app.dart';
import 'core/services/ad_service.dart';
import 'data/database/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FTS5 qo'llab-quvvatlash uchun sqlite3_flutter_libs dan SQLite ishlatish
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // AdMob ni ishga tushirish
  await AdService.instance.initialize();
  AdService.instance.loadInterstitialAd();
  AdService.instance.loadRewardedAd();

  // SharedPreferences orqali saqlanadigan provayderlar uchun override
  final overrides = await createPersistedProviderOverrides();

  runApp(
    ProviderScope(
      overrides: overrides,
      child: const TopsozApp(),
    ),
  );
}
