import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aquapath/core/theme/app_theme.dart';

/// Wraps a widget with [ProviderScope] + [MaterialApp] for widget tests.
Widget testApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
    ),
  );
}
