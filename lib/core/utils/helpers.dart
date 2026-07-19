import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shows a themed SnackBar.
void showAquaSnackBar(
  BuildContext context, {
  required String message,
  Color backgroundColor = AppColors.success,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration,
    ),
  );
}
