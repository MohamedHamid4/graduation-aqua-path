import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/inline_error_banner.dart';
import '../providers/auth_provider.dart';
import 'auth_text_field.dart';

/// The "forgot password" bottom sheet — sends a Firebase Auth password
/// reset email via [AuthNotifier.sendPasswordReset]. `sendPasswordResetEmail`
/// is role-agnostic (it only needs a Firebase Auth account to exist for
/// the given email, regardless of whether it's a resident, driver, or
/// organization account), so this single widget is shared by every login
/// surface rather than duplicated per role.
class ForgotPasswordSheet extends ConsumerStatefulWidget {
  const ForgotPasswordSheet({super.key});

  @override
  ConsumerState<ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<ForgotPasswordSheet> {
  final _emailCtrl = TextEditingController();
  String? _emailError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_emailCtrl.text.trim().isEmpty ||
        !Validators.isValidEmail(_emailCtrl.text)) {
      setState(() => _emailError = FailureMessages.emailInvalid);
      return;
    }
    ref.read(authFormProvider.notifier).sendPasswordReset(_emailCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authFormProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
        decoration: const BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              AppStrings.resetPasswordTitle,
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              AppStrings.resetPasswordDesc,
              style: GoogleFonts.cairo(
                fontSize: 12.5.sp,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
            SizedBox(height: 20.h),
            if (state.errorMessage != null)
              InlineErrorBanner(message: state.errorMessage!),
            if (state.resetEmailSent)
              InlineSuccessBanner(message: AppStrings.resetPasswordSent),
            if (!state.resetEmailSent) ...[
              AuthTextField(
                controller: _emailCtrl,
                label: AppStrings.emailLabel,
                hint: AppStrings.emailHint,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: state.isSubmitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        )
                      : Text(
                          AppStrings.resetPasswordButton,
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    AppStrings.closeButton,
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
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
