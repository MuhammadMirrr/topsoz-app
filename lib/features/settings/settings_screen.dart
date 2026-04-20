import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/ad_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Rewarded reklama holati
  int _watchedCount = 0;
  bool _isPremium = false;
  DateTime? _premiumExpiresAt;

  @override
  void initState() {
    super.initState();
    _loadRewardedState();
  }

  Future<void> _loadRewardedState() async {
    final count = await AdService.instance.getTodayRewardedCount();
    final premium = await AdService.instance.isPremiumActive();
    final expiresAt = await AdService.instance.getPremiumExpiresAt();
    if (mounted) {
      setState(() {
        _watchedCount = count;
        _isPremium = premium;
        _premiumExpiresAt = expiresAt;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final fontScale = ref.watch(fontScaleProvider);
    final wordCount = ref.watch(wordCountProvider);
    final definitionCount = ref.watch(definitionCountProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sozlamalar",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),

              // Ko'rinish
              _buildSection(
                context,
                title: "Ko'rinish",
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text("Qorong'i rejim"),
                    value: isDark,
                    activeTrackColor: AppColors.primary,
                    onChanged: (_) {
                      ref.read(themeModeProvider.notifier).toggle();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Matn o'lchami
              _buildSection(
                context,
                title: "Matn o'lchami",
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.text_fields_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            const Text("A", style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: fontScale,
                                min: 0.8,
                                max: 1.4,
                                divisions: 6,
                                activeColor: AppColors.primary,
                                label: '${(fontScale * 100).round()}%',
                                onChanged: (value) {
                                  ref
                                      .read(fontScaleProvider.notifier)
                                      .setFontScale(value);
                                },
                              ),
                            ),
                            const Text(
                              "A",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Namuna matni — So'z ta'rifi shu o'lchamda ko'rinadi",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 14 * fontScale),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Reklamasiz rejim (Rewarded reklama)
              _buildSupportSection(context),
              const SizedBox(height: 20),

              // Ilova haqida
              _buildSection(
                context,
                title: "Ilova haqida",
                children: [
                  _buildInfoTile(
                    context,
                    "Versiya",
                    "1.0.0",
                    Icons.info_outline_rounded,
                  ),
                  _buildInfoTile(
                    context,
                    "So'zlar soni",
                    wordCount.when(
                      data: (count) => _formatNumber(count),
                      loading: () => "...",
                      error: (_, _) => "—",
                    ),
                    Icons.library_books_rounded,
                  ),
                  _buildInfoTile(
                    context,
                    "Ta'riflar soni",
                    definitionCount.when(
                      data: (count) => _formatNumber(count),
                      loading: () => "...",
                      error: (_, _) => "—",
                    ),
                    Icons.translate_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ma'lumotlar
              _buildSection(
                context,
                title: "Ma'lumotlar",
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text("Qidiruv tarixini tozalash"),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => _showClearHistoryDialog(context),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      "Barcha sevimlilarni o'chirish",
                      style: TextStyle(color: AppColors.error),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => _showClearFavoritesDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ma'lumot manbalari
              _buildSection(
                context,
                title: "Ma'lumot manbalari",
                children: [
                  _buildSourceTile(context, "Kaikki.org (Wiktionary)", "CC-BY-SA"),
                  _buildSourceTile(context, "UzWordnet", "CC-BY-SA 4.0"),
                  _buildSourceTile(context, "Herve-Guerin Glossary", "Open Source"),
                  _buildSourceTile(context, "Vuizur Wiktionary Dict", "CC-BY-SA"),
                  _buildSourceTile(context, "Compact Dictionaries", "CC-BY-SA 3.0"),
                  _buildSourceTile(context, "kodchi/uzbek-words", "Open Source"),
                  _buildSourceTile(context, "SMenigat Common Words", "Open Source"),
                  _buildSourceTile(context, "nurullon/Dictionary", "Open Source"),
                ],
              ),
              const SizedBox(height: 20),

              // Litsenziya
              _buildSection(
                context,
                title: "Litsenziya",
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Ushbu ilova ochiq manba lug'at ma'lumotlaridan foydalanadi. "
                      "Barcha ma'lumotlar tegishli mualliflarning mulki hisoblanadi. "
                      "Ilova shaxsiy va ta'lim maqsadlarida bepul foydalanish uchun mo'ljallangan.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),

              // Ilova haqida dialog tugmasi
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    showAboutDialog(
                      context: context,
                      applicationName: "Topso'z",
                      applicationVersion: "1.0.0",
                      applicationIcon: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      children: [
                        Text(
                          "Topso'z — O'zbek-Ingliz-Rus offline lug'at ilovasi. "
                          "${wordCount.valueOrNull != null ? _formatNumber(wordCount.valueOrNull!) : '71,000'} "
                          "dan ortiq so'z va "
                          "${definitionCount.valueOrNull != null ? _formatNumber(definitionCount.valueOrNull!) : '20,000'} "
                          "dan ortiq ta'rif.",
                        ),
                      ],
                    );
                  },
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    "Ilova haqida",
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Reklamasiz rejim bo'limi
  // ============================================================

  Widget _buildSupportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isPremium ? "Premium faol" : "Reklamasiz rejim",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPremium
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : [const Color(0xFF9685FF), const Color(0xFF7B6BEB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (_isPremium ? AppColors.success : AppColors.primary)
                    .withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _isPremium
                            ? Icons.workspace_premium_rounded
                            : Icons.play_circle_outline_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPremium
                                ? "Reklamasiz rejim faol!"
                                : "3 ta video = 24 soat reklamasiz",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isPremium
                                ? "Barcha reklamalar o'chirilgan"
                                : "Qisqa videolarni ko'ring — butun kun tinch ishlating!",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isPremium && _premiumExpiresAt != null)
                  _buildPremiumTimer(context, _premiumExpiresAt!)
                else
                  _buildRewardedProgress(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumTimer(BuildContext context, DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              "$hours soat $minutes daqiqa qoldi",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Barcha reklamalar o'chirilgan",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardedProgress(BuildContext context) {
    final remaining = AdService.maxDailyRewarded - _watchedCount;
    final canWatch = remaining > 0;

    return Column(
      children: [
        // Progress ko'rsatgich — har bir video uchun alohida chiziq
        Row(
          children: List.generate(AdService.maxDailyRewarded, (i) {
            final isWatched = i < _watchedCount;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: i < AdService.maxDailyRewarded - 1 ? 6 : 0,
                ),
                height: 6,
                decoration: BoxDecoration(
                  color: isWatched
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          "$_watchedCount / ${AdService.maxDailyRewarded} video ko'rildi",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canWatch ? _showRewardedAd : null,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
            label: Text(
              canWatch
                  ? "Video ko'rish ($remaining qoldi)"
                  : "Bugun uchun tugadi",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  void _showRewardedAd() async {
    final messenger = ScaffoldMessenger.of(context);

    final shown = await AdService.instance.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        // Callback — reward olinganda
      },
    );

    if (!mounted) return;

    if (shown) {
      // Holatni qayta yuklash — UI darhol yangilanadi
      await _loadRewardedState();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isPremium
                ? "24 soatlik reklamasiz rejim faollashdi!"
                : "Rahmat! Yana ${AdService.maxDailyRewarded - _watchedCount} ta video qoldi",
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: _isPremium ? AppColors.success : AppColors.primary,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text("Reklama hozircha tayyor emas. Keyinroq urinib ko'ring."),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ============================================================
  // Yordamchi widgetlar
  // ============================================================

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color ??
              AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSourceTile(BuildContext context, String name, String license) {
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.source_rounded,
        color: AppColors.primary,
        size: 20,
      ),
      title: Text(name, style: const TextStyle(fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          license,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Tarixni tozalash"),
        content: const Text(
          "Barcha qidiruv tarixi o'chiriladi. Davom etasizmi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Bekor qilish"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final historyRepo =
                  await ref.read(historyRepositoryProvider.future);
              await historyRepo.clear();
              ref.invalidate(recentSearchesProvider);
              ref.invalidate(historyListProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Qidiruv tarixi tozalandi"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text("Tozalash"),
          ),
        ],
      ),
    );
  }

  void _showClearFavoritesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Sevimlilarni o'chirish"),
        content: const Text(
          "Barcha sevimli so'zlar o'chiriladi. Bu amalni qaytarib bo'lmaydi. Davom etasizmi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Bekor qilish"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final favRepo =
                  await ref.read(favoritesRepositoryProvider.future);
              await favRepo.removeAll();
              ref.invalidate(favoritesListProvider);
              ref.invalidate(searchResultsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Barcha sevimlilar o'chirildi"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
  }
}
