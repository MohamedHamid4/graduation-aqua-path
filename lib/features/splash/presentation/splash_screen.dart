import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/user_role.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../driver/domain/repositories/driver_repository.dart';

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
    final user = authRepo.currentUser;

    if (user == null) {
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

    if (!mounted) return;
    if (role == UserRole.organization) {
      context.go(RouteNames.orgDashboard);
      return;
    }
    if (role == UserRole.driver) {
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
        context.go('/driver/schedule');
        return;
      }
    }

    final pendingRole = await storage.pendingAccountRole;

    if (!mounted) return;

    if (pendingRole == 'driver') {
      context.go('/driver/register');
      return;
    }

    final onboardingDone = await storage.isOnboardingComplete;

    if (!mounted) return;

    if (!onboardingDone) {
      context.go('/onboarding');
      return;
    }

    final registrationDone = await storage.isRegistrationComplete;

    if (!mounted) return;

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
