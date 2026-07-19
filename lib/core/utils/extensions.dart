import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}

extension StringExtensions on String {
  bool get isNullOrEmpty => isEmpty;
  String get trimmed => trim();
}

extension IntExtensions on int {
  /// Formats minutes as Arabic human-readable duration.
  String toArabicDuration() {
    if (this <= 0) return 'وصلت!';
    if (this < 60) return '$this دقيقة';
    final hours = this ~/ 60;
    final mins = this % 60;
    if (mins == 0) return '$hours ساعة';
    return '$hours س و $mins د';
  }
}

extension DoubleExtensions on double {
  String toKm() => '${toStringAsFixed(1)} كم';
}

extension DateTimeArabicExt on DateTime {
  /// Returns a human-readable Arabic relative time string, e.g. "منذ 5 دقيقة".
  String toArabicTimeAgo() {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'منذ ${diff.inSeconds} ثانية';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}
