import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/inline_error_banner.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isDriver = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError =
          _nameCtrl.text.trim().isEmpty ? FailureMessages.nameRequired : null;
      _emailError = _emailCtrl.text.trim().isEmpty
          ? FailureMessages.emailRequired
          : !Validators.isValidEmail(_emailCtrl.text)
              ? FailureMessages.emailInvalid
              : null;
      _passwordError = _passwordCtrl.text.isEmpty
          ? FailureMessages.passwordRequired
          : Validators.passwordError(_passwordCtrl.text);
      _confirmError = _confirmCtrl.text != _passwordCtrl.text
          ? FailureMessages.passwordsDoNotMatch
          : null;
    });
    return _nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmError == null;
  }

  void _submit() {
    if (!_validate()) return;
    // Persisted BEFORE the Firebase call so the router's redirect logic
    // can read it the instant auth state flips to signed-in — Firestore
    // has no driver/household profile yet at that point to tell the two
    // apart, so this local flag is the only signal available in time.
    GetIt.I<SecureStorageService>()
        .setPendingAccountRole(_isDriver ? 'driver' : 'resident');
    ref.read(authFormProvider.notifier).signUp(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authFormProvider);

    ref.listen<AuthFormState>(authFormProvider, (_, next) {
      if (next.isSuccess) {
        ref.read(authFormProvider.notifier).consumeSuccess();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
          children: [
            Text(
              AppStrings.signupTitle,
              style: GoogleFonts.cairo(
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(duration: 400.ms),
            SizedBox(height: 6.h),
            Text(
              AppStrings.signupSubtitle,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                color: AppColors.textMuted,
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
            SizedBox(height: 22.h),
            Text(
              'نوع الحساب',
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _AccountTypeCard(
                    icon: Icons.home_rounded,
                    label: 'مستفيد',
                    subtitle: 'أستقبل توصيل المياه',
                    selected: !_isDriver,
                    onTap: () => setState(() => _isDriver = false),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _AccountTypeCard(
                    icon: Icons.local_shipping_rounded,
                    label: 'سائق شاحنة',
                    subtitle: 'أوصّل المياه',
                    selected: _isDriver,
                    onTap: () => setState(() => _isDriver = true),
                  ),
                ),
              ],
            ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
            SizedBox(height: 24.h),
            if (state.errorMessage != null)
              InlineErrorBanner(message: state.errorMessage!),
            AuthTextField(
              controller: _nameCtrl,
              label: AppStrings.fullNameLabel,
              hint: AppStrings.fullNameHint,
              icon: Icons.person_outline_rounded,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            SizedBox(height: 16.h),
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
            SizedBox(height: 16.h),
            AuthTextField(
              controller: _confirmCtrl,
              label: AppStrings.confirmPasswordLabel,
              hint: AppStrings.confirmPasswordHint,
              icon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              errorText: _confirmError,
              onChanged: (_) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20.w,
                  color: AppColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            SizedBox(height: 28.h),
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
                        AppStrings.signupButton,
                        style: GoogleFonts.cairo(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.haveAccount,
                  style: GoogleFonts.cairo(
                    fontSize: 12.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                  child: Text(
                    AppStrings.goToLogin,
                    style: GoogleFonts.cairo(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderDefault,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26.w,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: GoogleFonts.cairo(
                fontSize: 9.5.sp,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
