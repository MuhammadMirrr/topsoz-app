import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../data/database/providers.dart';
import '../../data/models/word.dart';

enum FavoritesSort { byDate, byAlphabet }

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  FavoritesSort _sort = FavoritesSort.byDate;
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Word> _filterAndSort(List<Word> items) {
    var result = items.toList();

    // Qidiruv filtri
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((w) =>
        w.word.toLowerCase().contains(q) ||
        w.wordCyrillic.toLowerCase().contains(q)
      ).toList();
    }

    // Tartiblash
    if (_sort == FavoritesSort.byAlphabet) {
      result.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final favAsync = ref.watch(favoritesListProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sarlavha
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isSearching)
                    Text(
                      "Sevimlilar",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (_isSearching)
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: "Sevimlilardan qidiring...",
                          hintStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isSearching ? Icons.close_rounded : Icons.search_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchQuery = '';
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      PopupMenuButton<FavoritesSort>(
                        icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary),
                        onSelected: (sort) => setState(() => _sort = sort),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: FavoritesSort.byDate,
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                  size: 20,
                                  color: _sort == FavoritesSort.byDate ? AppColors.primary : AppColors.textLight),
                                const SizedBox(width: 8),
                                Text("Sana bo'yicha"),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: FavoritesSort.byAlphabet,
                            child: Row(
                              children: [
                                Icon(Icons.sort_by_alpha_rounded,
                                  size: 20,
                                  color: _sort == FavoritesSort.byAlphabet ? AppColors.primary : AppColors.textLight),
                                const SizedBox(width: 8),
                                Text("Alifbo bo'yicha"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (favAsync.valueOrNull?.isNotEmpty == true && !_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  "${favAsync.valueOrNull?.length ?? 0} ta so'z",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: favAsync.when(
                data: (items) {
                  final filtered = _filterAndSort(items);
                  if (items.isEmpty) return _buildEmptyState(context);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64,
                            color: AppColors.textLight.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            "\"$_searchQuery\" topilmadi",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _buildList(context, ref, filtered);
                },
                loading: () => const ShimmerList(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        Text('Xatolik yuz berdi', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Sevimlilarni yuklashda xatolik',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 80,
            color: AppColors.textLight.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            "Hali sevimli so'z yo'q",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "So'z sahifasida yurak belgisini bosing",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Word> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final word = items[index];
        final firstDef = word.definitions.isNotEmpty
            ? word.definitions.first.definition
            : '';

        return Dismissible(
          key: ValueKey(word.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete_rounded, color: AppColors.error),
          ),
          onDismissed: (_) async {
            HapticFeedback.lightImpact();
            final favRepo = await ref.read(favoritesRepositoryProvider.future);
            await favRepo.remove(word.id);
            ref.invalidate(favoritesListProvider);

            if (context.mounted) {
              showCustomSnackbar(
                context,
                message: "${word.word} o'chirildi",
                type: SnackType.info,
                actionLabel: "Qaytarish",
                onAction: () async {
                  await favRepo.toggle(word.id);
                  ref.invalidate(favoritesListProvider);
                },
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => context.push('/word/${word.id}'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.word,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (firstDef.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                firstDef,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
