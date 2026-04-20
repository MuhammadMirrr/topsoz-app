import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? const [
                      Color(0xFF2A2A42),
                      Color(0xFF3D3D5C),
                      Color(0xFF2A2A42),
                    ]
                  : const [
                      Color(0xFFEBEBF4),
                      Color(0xFFF4F4F4),
                      Color(0xFFEBEBF4),
                    ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Qidiruv natijasi uchun shimmer placeholder
class ShimmerResultCard extends StatelessWidget {
  const ShimmerResultCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.textLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.textLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.textLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir nechta shimmer kartalar ro'yxati
class ShimmerList extends StatelessWidget {
  final int itemCount;

  const ShimmerList({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: List.generate(itemCount, (_) => const ShimmerResultCard()),
        ),
      ),
    );
  }
}

/// So'z tafsiloti uchun shimmer
class ShimmerWordDetail extends StatelessWidget {
  const ShimmerWordDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color;

    return ShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 180, height: 28, decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 8),
                  Container(width: 140, height: 20, decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(width: 60, height: 28, decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12))),
                    const SizedBox(width: 8),
                    Container(width: 80, height: 28, decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12))),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 100, height: 20, decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 16),
                  ...List.generate(3, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8))),
                      const SizedBox(width: 12),
                      Expanded(child: Container(height: 16, decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)))),
                    ]),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
