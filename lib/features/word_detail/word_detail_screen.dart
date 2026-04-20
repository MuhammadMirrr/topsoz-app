import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../data/database/providers.dart';
import '../../data/models/word.dart';

class WordDetailScreen extends ConsumerWidget {
  final int wordId;

  const WordDetailScreen({super.key, required this.wordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordAsync = ref.watch(wordDetailProvider(wordId));

    return Scaffold(
      body: wordAsync.when(
        data: (word) {
          if (word == null) {
            return const Center(child: Text("So'z topilmadi"));
          }
          return _buildContent(context, ref, word);
        },
        loading: () => const ShimmerWordDetail(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Xatolik yuz berdi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'So\'z ma\'lumotlarini yuklashda xatolik',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Word word) {
    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          floating: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                word.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: word.isFavorite ? AppColors.secondary : null,
              ),
              onPressed: () async {
                final favRepo = await ref.read(
                  favoritesRepositoryProvider.future,
                );
                await favRepo.toggle(word.id);
                HapticFeedback.lightImpact();
                ref.invalidate(wordDetailProvider(wordId));
                ref.invalidate(searchResultsProvider);
                ref.invalidate(favoritesListProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () {
                final defs = word.definitions
                    .map((d) => d.definition)
                    .join(', ');
                Share.share('${word.word} — $defs\n\nTopso\'z lug\'atidan');
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                final defs = word.definitions
                    .map((d) => d.definition)
                    .join('\n');
                Clipboard.setData(ClipboardData(text: '${word.word}\n$defs'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Nusxalandi"),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
          ],
        ),

        // So'z header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (word.wordCyrillic.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      word.wordCyrillic,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.textLight,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (word.partOfSpeech.isNotEmpty)
                        _buildChip(word.partOfSpeech, AppColors.primary),
                      if (word.pronunciation.isNotEmpty)
                        _buildChip(word.pronunciation, AppColors.secondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Ta'riflar
        if (word.definitions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ta'riflar",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildGroupedDefinitions(context, word.definitions),
                  ],
                ),
              ),
            ),
          ),

        // Etimologiya
        if (word.etymology.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Etimologiya",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      word.etymology,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Banner reklama
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Center(child: BannerAdWidget()),
          ),
        ),

        // Bo'sh joy
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static const _langLabels = {
    'en': 'Inglizcha',
    'ru': 'Ruscha',
    'uz': "O'zbekcha",
  };

  static const _langColors = {
    'en': AppColors.primary,
    'ru': AppColors.secondary,
    'uz': AppColors.success,
  };

  List<Widget> _buildGroupedDefinitions(
    BuildContext context,
    List<Definition> definitions,
  ) {
    final groups = <String, List<Definition>>{};
    for (final def in definitions) {
      final lang = def.targetLanguage.isEmpty ? 'en' : def.targetLanguage;
      groups.putIfAbsent(lang, () => []).add(def);
    }

    // Tartib: en, ru, qolganlar
    final orderedKeys = ['en', 'ru', 'uz']
        .where(groups.containsKey)
        .followedBy(groups.keys.where((k) => !['en', 'ru', 'uz'].contains(k)))
        .toList();

    final showHeaders = orderedKeys.length > 1;
    final widgets = <Widget>[];

    for (final lang in orderedKeys) {
      final defs = groups[lang]!;
      final color = _langColors[lang] ?? AppColors.primary;

      if (showHeaders) {
        widgets.add(_buildLanguageHeader(context, lang));
      }
      for (var i = 0; i < defs.length; i++) {
        widgets.add(
          _buildDefinitionItem(
            context,
            i + 1,
            defs[i],
            accentColor: showHeaders ? color : null,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildLanguageHeader(BuildContext context, String langCode) {
    final label = _langLabels[langCode] ?? langCode;
    final color = _langColors[langCode] ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDefinitionItem(
    BuildContext context,
    int num,
    Definition def, {
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$num',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.definition,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (def.source.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    def.source,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextLight
                          : AppColors.textLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (def.exampleSource.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurfaceLight
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.exampleSource,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        if (def.exampleTarget.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            def.exampleTarget,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
