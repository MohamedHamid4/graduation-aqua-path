import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/inline_error_banner.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/forgot_password_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = _emailCtrl.text.trim().isEmpty
          ? FailureMessages.emailRequired
          : !Validators.isValidEmail(_emailCtrl.text)
              ? FailureMessages.emailInvalid
              : null;
      _passwordError =
          _passwordCtrl.text.isEmpty ? FailureMessages.passwordRequired : null;
    });
    return _emailError == null && _passwordError == null;
  }

  void _submit() {
    if (!_validate()) return;
    ref.read(authFormProvider.notifier).signIn(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
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
    final state = ref.watch(authFormProvider);

    // Success is handled by the router's redirect (authStateProvider),
    // so we don't need to navigate manually here — just clear the flag.
    ref.listen<AuthFormState>(authFormProvider, (_, next) {
      if (next.isSuccess) {
        ref.read(authFormProvider.notifier).consumeSuccess();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(24.w, 40.h, 24.w, 24.h),
          children: [
            // ── Logo ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: 84.w,
                height: 84.w,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(18.w),
                  child: Image.asset(
                    'assets/images/aquapath_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ).animate().scale(
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.6, 0.6),
                ),

            SizedBox(height: 24.h),

            Text(
              AppStrings.loginTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

            SizedBox(height: 6.h),

            Text(
              AppStrings.loginSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                color: AppColors.textMuted,
              ),
            ).animate(delay: 150.ms).fadeIn(duration: 400.ms),

            SizedBox(height: 32.h),

            if (state.errorMessage != null)
              InlineErrorBanner(message: state.errorMessage!),

            AuthTextField(
              controller: _emailCtrl,
              label: AppStrings.emailLabel,
              hint: AppStrings.emailHint,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),

            SizedBox(height: 16.h),

            AuthTextField(
              controller: _passwordCtrl,
              label: AppStrings.passwordLabel,
              hint: AppStrings.passwordHint,
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              errorText: _passwordError,
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20.w,
                  color: AppColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),

            SizedBox(height: 10.h),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _showForgotPasswordSheet,
                child: Text(
                  AppStrings.forgotPassword,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            SizedBox(height: 16.h),

            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: state.isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: state.isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      )
                    : Text(
                        AppStrings.loginButton,
                        style: GoogleFonts.cairo(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

            SizedBox(height: 24.h),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.noAccount,
                  style: GoogleFonts.cairo(
                    fontSize: 12.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  child: Text(
                    AppStrings.createAccount,
                    style: GoogleFonts.cairo(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            // Entry point for organization accounts — they have a dedicated
            // login screen and never go through the resident/driver flow.
            Center(
              child: TextButton(
                onPressed: () => context.push(RouteNames.orgLogin),
                child: Text(
                  AppStrings.orgLoginEntry,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
