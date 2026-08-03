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

# flutter_secure_storage — encryptedSharedPreferences: true (see
# SecureStorageService) uses androidx.security.crypto's EncryptedSharedPreferences,
# which is backed by Tink at runtime via reflection. Neither ships its own
# consumer ProGuard rules, so without these keeps, R8 can strip/rename
# classes Tink needs and every read/write throws — SecureStorageService
# swallows that exception and returns null, which silently resets
# onboarding/registration/session flags ONLY in a minified release build.
-keep class com.google.crypto.tink.** { *; }
-keep class androidx.security.crypto.** { *; }
-keepclassmembers class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# Play Core (referenced by Flutter's deferred-components support even
# though this app doesn't use deferred components) — without these, R8
# fails with "Missing classes detected" for SplitCompatApplication,
# SplitInstallManager, etc.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
