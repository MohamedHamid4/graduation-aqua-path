import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/user_role.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/router/route_names.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:get_it/get_it.dart';

/// A dedicated sign-in screen for the Organization role.
///
/// Deliberately not a variant of the resident/driver [LoginScreen] — the
/// requirement is a fully separate door, and reusing the same widget
/// (even with a "mode" flag) would make it too easy for a future edit to
/// accidentally blur that boundary. Access is denied outright if the
/// signed-in account's `role` claim isn't `organization`, even if the
/// email/password are correct — this screen enforces that explicitly in
/// addition to the router guard, so the failure message is specific
/// ("this account has no organization access") rather than a generic
/// redirect the person has to puzzle out.
class OrgLoginScreen extends StatefulWidget {
  const OrgLoginScreen({super.key});

  @override
  State<OrgLoginScreen> createState() => _OrgLoginScreenState();
}

class _OrgLoginScreenState extends State<OrgLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final authRepo = GetIt.I<AuthRepository>();
    final result = await authRepo.signInWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    await result.fold(
      (failure) async {
        setState(() {
          _isSubmitting = false;
          _error = FailureMessages.fromFailure(failure);
        });
      },
      (_) async {
        final role = await authRepo.getCurrentRole() ??
            await authRepo.waitForRoleClaim();
        if (role != UserRole.organization) {
          await authRepo.signOut();
          setState(() {
            _isSubmitting = false;
            _error = 'هذا الحساب لا يملك صلاحية الدخول كمؤسسة';
          });
          return;
        }
        if (mounted) context.go(RouteNames.orgDashboard);
      },
    );
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ForgotPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.apartment_rounded, size: 56.w, color: Colors.white),
                SizedBox(height: 12.h),
                Text(
                  'AquaPath — لوحة المؤسسة',
                  style: GoogleFonts.cairo(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'دخول مخصص لحسابات المؤسسة فقط',
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 32.h),
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _showForgotPasswordSheet,
                          child: Text(
                            AppStrings.forgotPassword,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 12.h),
                        Text(
                          _error!,
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                      SizedBox(height: 20.h),
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'تسجيل الدخول',
                                  style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'حسابات المؤسسة تُنشأ فقط من قبل مؤسسة أخرى مصرّح لها — لا يوجد تسجيل ذاتي.',
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.cairo(fontSize: 11.sp, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
