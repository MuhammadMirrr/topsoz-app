import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/search_result.dart';

class ResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const ResultCard({super.key, required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              result.word,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (result.wordCyrillic.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                result.wordCyrillic,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.darkTextLight
                                      : AppColors.textLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (result.partOfSpeech.isNotEmpty)
                            _buildMetaChip(
                              context,
                              label: result.partOfSpeech,
                              color: AppColors.primary,
                            ),
                          if (result.duplicateCount > 1)
                            _buildMetaChip(
                              context,
                              label: '${result.duplicateCount} manba',
                              color: AppColors.secondary,
                            ),
                          if (result.matchedTargetLanguage != null)
                            _buildMetaChip(
                              context,
                              label: _languageLabel(
                                result.matchedTargetLanguage!,
                              ),
                              color: AppColors.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.firstDefinition,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).brightness == Brightness.dark
              ? color.withValues(alpha: 0.9)
              : color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _languageLabel(String lang) {
    switch (lang) {
      case 'en':
        return "Inglizcha ta'rif";
      case 'ru':
        return "Ruscha ta'rif";
      default:
        return "Ta'rif mosligi";
    }
  }
}
