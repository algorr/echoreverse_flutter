import 'package:flutter/material.dart';

enum SnackBarType { success, error, info, warning }

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final (Color bgColor, Color iconColor, IconData icon) = switch (type) {
      SnackBarType.success => (
          const Color(0xFF065F46),
          const Color(0xFF10B981),
          Icons.check_circle_outline,
        ),
      SnackBarType.error => (
          const Color(0xFF7F1D1D),
          const Color(0xFFEF4444),
          Icons.error_outline,
        ),
      SnackBarType.warning => (
          const Color(0xFF78350F),
          const Color(0xFFF59E0B),
          Icons.warning_amber_rounded,
        ),
      SnackBarType.info => (
          const Color(0xFF164E63),
          const Color(0xFF22D3EE),
          Icons.info_outline,
        ),
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: iconColor.withValues(alpha: 0.3)),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
