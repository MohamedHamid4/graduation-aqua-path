# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Hive
-keep class * extends hive.HiveObject { *; }

# Play Core (referenced by Flutter's deferred-components support even
# though this app doesn't use deferred components) — without these, R8
# fails with "Missing classes detected" for SplitCompatApplication,
# SplitInstallManager, etc.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
