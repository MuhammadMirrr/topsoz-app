import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum SnackType { success, error, info }

void showCustomSnackbar(
  BuildContext context, {
  required String message,
  SnackType type = SnackType.success,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final (color, icon) = switch (type) {
    SnackType.success => (AppColors.success, Icons.check_circle_rounded),
    SnackType.error => (AppColors.error, Icons.error_rounded),
    SnackType.info => (AppColors.primary, Icons.info_rounded),
  };

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: color,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction ?? () {},
            )
          : null,
    ),
  );
}
