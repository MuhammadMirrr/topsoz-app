import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../data/database/providers.dart';
import '../../data/repositories/history_repository.dart';

class _HistoryGroup {
  final String label;
  final List<HistoryEntry> entries;
  const _HistoryGroup({required this.label, required this.entries});
}

List<_HistoryGroup> _groupByDate(List<HistoryEntry> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));

  final groups = <String, List<HistoryEntry>>{};

  for (final entry in items) {
    final date = DateTime.tryParse(entry.searchedAt);
    final String label;
    if (date == null) {
      label = "Boshqa";
    } else {
      final entryDate = DateTime(date.year, date.month, date.day);
      if (entryDate == today) {
        label = "Bugun";
      } else if (entryDate == yesterday) {
        label = "Kecha";
      } else if (entryDate.isAfter(weekAgo)) {
        label = "Shu hafta";
      } else {
        label = "Oldingi";
      }
    }
    groups.putIfAbsent(label, () => []).add(entry);
  }

  // Tartib
  const order = ["Bugun", "Kecha", "Shu hafta", "Oldingi", "Boshqa"];
  return order
      .where(groups.containsKey)
      .map((label) => _HistoryGroup(label: label, entries: groups[label]!))
      .toList();
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyListProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tarix",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (historyAsync.valueOrNull?.isNotEmpty == true)
                    TextButton(
                      onPressed: () async {
                        final repo = await ref.read(
                          historyRepositoryProvider.future,
                        );
                        await repo.clear();
                        ref.invalidate(historyListProvider);
                      },
                      child: const Text(
                        "Tozalash",
                        style: TextStyle(color: AppColors.secondary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: historyAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 80,
                            color: AppColors.textLight.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Qidiruv tarixi bo'sh",
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sana bo'yicha guruhlash
                  final grouped = _groupByDate(items);

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final group = grouped[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index > 0) const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              group.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ),
                          ...group.entries.map(
                            (entry) => _buildHistoryItem(context, ref, entry),
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const ShimmerList(),
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
                          'Tarixni yuklashda xatolik',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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

  Widget _buildHistoryItem(
    BuildContext context,
    WidgetRef ref,
    HistoryEntry entry,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            if (entry.wordId != null) {
              context.push('/word/${entry.wordId}');
            } else {
              ref.read(searchInputProvider.notifier).state = entry.query;
              ref.read(searchQueryProvider.notifier).state = entry.query;
              context.go('/search');
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.textLight,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.query,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const Icon(
                  Icons.north_west_rounded,
                  color: AppColors.textLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
