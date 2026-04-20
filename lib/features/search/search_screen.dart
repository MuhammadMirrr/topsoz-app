import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/debouncer.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../core/widgets/native_ad_widget.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../data/database/providers.dart';
import '../../data/models/search_result.dart';
import '../../data/models/word.dart';
import 'widgets/language_selector.dart';
import 'widgets/result_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchInputProvider);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchInputProvider.notifier).state = value;
    _debouncer.run(() {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _applySearchText(String value) {
    _debouncer.cancel();
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    ref.read(searchInputProvider.notifier).state = value;
    ref.read(searchQueryProvider.notifier).state = value.trim();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(searchInputProvider, (previous, next) {
      if (_controller.text == next) return;
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });

    final inputQuery = ref.watch(searchInputProvider);
    final debouncedQuery = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final trimmedInput = inputQuery.trim();
    final isDebouncing =
        trimmedInput.isNotEmpty && trimmedInput != debouncedQuery.trim();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    "Topso'z",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Lug'at",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const LanguageSelector(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                    if (_focusNode.hasFocus)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _debouncer.cancel();
                    ref.read(searchQueryProvider.notifier).state = value.trim();
                    FocusScope.of(context).unfocus();
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "So'z qidiring...",
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextLight
                          : AppColors.textLight.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: _focusNode.hasFocus
                            ? AppColors.primary
                            : Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextLight
                            : AppColors.textLight,
                        size: 24,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 24,
                    ),
                    suffixIcon: trimmedInput.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              tooltip: "Tozalash",
                              icon: Icon(
                                Icons.close_rounded,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.darkTextLight
                                    : AppColors.textLight,
                                size: 20,
                              ),
                              onPressed: () {
                                _applySearchText('');
                              },
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: trimmedInput.isEmpty
                  ? _buildEmptyState()
                  : isDebouncing
                  ? const ShimmerList()
                  : _buildSearchResults(results),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final wordOfDay = ref.watch(wordOfDayProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentSearches(),
          const SizedBox(height: 24),
          Text("Kun so'zi", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          wordOfDay.when(
            data: (word) {
              if (word == null) return const SizedBox.shrink();
              return _buildWordOfDayCard(word);
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Kun so'zini yuklashda xatolik",
                style: TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    final recentSearches = ref.watch(recentSearchesProvider);

    return recentSearches.when(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Oxirgi qidiruvlar",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () async {
                    final historyRepo = await ref.read(
                      historyRepositoryProvider.future,
                    );
                    await historyRepo.clear();
                    ref.invalidate(recentSearchesProvider);
                  },
                  child: const Text(
                    "Tozalash",
                    style: TextStyle(color: AppColors.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries
                  .map(
                    (entry) => ActionChip(
                      label: Text(entry.query),
                      onPressed: () => _applySearchText(entry.query),
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Oxirgi qidiruvlarni yuklashda xatolik",
          style: TextStyle(color: AppColors.textLight, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildWordOfDayCard(Word word) {
    final firstDef = word.definitions.isNotEmpty
        ? word.definitions.first.definition
        : '';

    return GestureDetector(
      onTap: () => context.push('/word/${word.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF7B6BEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(
                  "Kun so'zi",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              word.word,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (word.wordCyrillic.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                word.wordCyrillic,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white60),
              ),
            ],
            if (word.partOfSpeech.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  word.partOfSpeech,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
            if (firstDef.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                firstDef,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<SearchResult>> results) {
    return results.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextLight.withValues(alpha: 0.5)
                      : AppColors.textLight.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  "Hech narsa topilmadi",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextLight
                        : AppColors.textLight,
                  ),
                ),
              ],
            ),
          );
        }

        const nativeAdInterval = 10;
        final nativeAdCount = items.length >= nativeAdInterval
            ? (items.length ~/ nativeAdInterval)
            : 0;
        final totalCount = items.length + nativeAdCount;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (nativeAdCount > 0 &&
                index > 0 &&
                (index + 1) % (nativeAdInterval + 1) == 0) {
              return const NativeAdWidget();
            }

            final realIndex = nativeAdCount > 0
                ? index - (index ~/ (nativeAdInterval + 1))
                : index;

            if (realIndex >= items.length) return const SizedBox.shrink();

            return ResultCard(
              result: items[realIndex],
              onTap: () async {
                FocusScope.of(context).unfocus();
                final historyRepo = await ref.read(
                  historyRepositoryProvider.future,
                );
                await historyRepo.add(
                  _controller.text.trim(),
                  wordId: items[realIndex].wordId,
                );
                ref.invalidate(recentSearchesProvider);
                ref.invalidate(historyListProvider);
                if (context.mounted) {
                  context.push('/word/${items[realIndex].wordId}');
                }
              },
            );
          },
        );
      },
      loading: () => const ShimmerList(),
      error: (e, _) => Center(child: Text('Xatolik: $e')),
    );
  }
}
