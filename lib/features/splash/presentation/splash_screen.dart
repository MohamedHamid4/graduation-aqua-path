import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/user_role.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/router/route_names.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../driver/domain/repositories/driver_repository.dart';

/// Cold-start diagnostic for the session-persistence bug (reported STILL
/// happening after two earlier fixes). Deliberately NOT gated on
/// kDebugMode:
///  - `debugPrint` always prints (even in a release APK) and is visible
///    over `adb logcat` on a USB-connected device — the one channel that
///    survives a --release build, since AppLogger's own ConsoleOutput is
///    kDebugMode-only.
///  - AppLogger.warning also reaches Crashlytics in release (see
///    AppLogger's _ReleaseOutput — only warning/error/fatal are forwarded),
///    so the same evidence is retrievable after the fact from the
///    Crashlytics console without a USB cable, at the cost of a delay.
/// Safe to remove once the real cause is confirmed from a real device.
void _splashLog(String message) {
  debugPrint('[SplashDiag] $message');
  AppLogger.warning(message, tag: 'SplashDiag');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 2600),
      _decideNextRoute,
    );
  }

  Future<void> _decideNextRoute() async {
    if (!mounted) return;

    final authRepo = GetIt.I<AuthRepository>();

    // Logged BEFORE awaiting the stream: if the synchronous getter
    // already shows a restored user here, but the stream below still
    // resolves to null, that's direct evidence the stream (not the
    // underlying native session) is the broken link.
    _splashLog(
      'cold start: synchronous currentUser = '
      '${authRepo.currentUser?.uid ?? "null"}',
    );

    // Firebase Auth's authoritative signal, not the synchronous
    // `currentUser` getter: `currentUser` can transiently read null on a
    // cold start, before the SDK finishes restoring a persisted session
    // from disk (slower on some devices / right after a reboot) —
    // reading it too early used to bounce a genuinely signed-in user to
    // the login screen. `authStateChanges`'s first emission is
    // guaranteed to reflect the actually-restored session, however long
    // that takes, instead of gambling that the branding delay above was
    // always long enough.
    final user = await authRepo.authStateChanges.first;

    _splashLog('authStateChanges.first resolved to uid = ${user?.uid ?? "null"}');

    if (!mounted) return;

    if (user == null) {
      _splashLog('routing to /login — no restored session');
      if (mounted) context.go(RouteNames.login);
      return;
    }

    // Cached claim first (fast, no network) — covers the overwhelmingly
    // common case of a returning session whose token already reflects
    // their real role.
    var role = await authRepo.getCurrentRole();

    // The cached ID token can be stale — e.g. it was persisted before a
    // driver/organization claim was actually granted, or simply before
    // the app was last closed. Never treat an unresolved role here as
    // "must be a resident": a forced refresh is one network round trip
    // and is authoritative. This is the fix for a driver whose cached
    // token predated their claim falling straight through to the
    // resident flow on a cold restart.
    if (!mounted) return;
    role ??= await authRepo.refreshRoleClaim();

    _splashLog('resolved role = ${role?.name ?? "null"} for uid=${user.uid}');

    if (!mounted) return;
    if (role == UserRole.organization) {
      _splashLog('routing to org dashboard');
      context.go(RouteNames.orgDashboard);
      return;
    }
    if (role == UserRole.driver) {
      _splashLog('routing to driver schedule');
      context.go('/driver/schedule');
      return;
    }

    final storage = GetIt.I<SecureStorageService>();

    if (role == null) {
      // Covers pre-migration driver accounts that never got a claim at
      // all — the one case a token refresh can't resolve.
      final isDriver = await GetIt.I<DriverRepository>().isDriver(user.uid);
      if (!mounted) return;
      if (isDriver) {
        _splashLog('routing to driver schedule (pre-migration isDriver check)');
        context.go('/driver/schedule');
        return;
      }
    }

    final pendingRole = await storage.pendingAccountRole;

    if (!mounted) return;

    if (pendingRole == 'driver') {
      _splashLog('routing to driver registration (pendingAccountRole)');
      context.go('/driver/register');
      return;
    }

    final onboardingDone = await storage.isOnboardingComplete;

    if (!mounted) return;

    if (!onboardingDone) {
      _splashLog(
        'routing to /onboarding — isOnboardingComplete read back false. '
        'If this account already finished onboarding before, SecureStorage '
        'failed to read its persisted value (see AndroidX Security Crypto '
        '/ Tink ProGuard keep rules in proguard-rules.pro).',
      );
      context.go('/onboarding');
      return;
    }

    final registrationDone = await storage.isRegistrationComplete;

    if (!mounted) return;

    _splashLog(
      'resident final route: registrationDone=$registrationDone '
      '(routing to ${registrationDone ? "/" : "/register"})',
    );
    context.go(
      registrationDone ? '/' : '/register',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 260.w,
                    height: 260.w,
                    child: Image.asset(
                      'assets/images/splash_logo.png',
                      fit: BoxFit.contain,
                    ),
                  )
                      .animate()
                      .scale(
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(
                          0.7,
                          0.7,
                        ),
                      )
                      .fadeIn(
                        duration: 600.ms,
                      ),
                  SizedBox(height: 24.h),
                  Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.aquaBlue,
                      letterSpacing: 1.5,
                    ),
                  )
                      .animate(
                        delay: 300.ms,
                      )
                      .fadeIn(
                        duration: 600.ms,
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                      ),
                  SizedBox(height: 10.h),
                  Text(
                    AppStrings.appTagline,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      .animate(
                        delay: 600.ms,
                      )
                      .fadeIn(
                        duration: 600.ms,
                      ),
                  SizedBox(height: 80.h),
                  Text(
                    AppStrings.appDescription,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                      height: 1.7,
                    ),
                  )
                      .animate(
                        delay: 900.ms,
                      )
                      .fadeIn(
                        duration: 700.ms,
                      ),
                  SizedBox(height: 28.h),
                  SizedBox(
                    width: 28.w,
                    height: 28.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.pathGreen,
                      ),
                    ),
                  )
                      .animate(
                        delay: 1200.ms,
                      )
                      .fadeIn(
                        duration: 400.ms,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
