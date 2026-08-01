import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/inline_error_banner.dart';
import '../../../shared/widgets/area_dropdown.dart';
import 'providers/driver_registration_provider.dart';

/// Driver-side onboarding form — collects the truck and license details
/// that let the router treat this authenticated user as a driver rather
/// than a resident on all subsequent app launches (see
/// [DriverRepository.isDriver]).
class DriverRegisterScreen extends ConsumerStatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  ConsumerState<DriverRegisterScreen> createState() =>
      _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends ConsumerState<DriverRegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '10000');

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _licenseCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverRegistrationProvider);
    final notifier = ref.read(driverRegistrationProvider.notifier);

    ref.listen<DriverRegistrationState>(driverRegistrationProvider, (_, next) {
      if (next.isSuccess) context.go('/driver/schedule');
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          'تسجيل بيانات السائق',
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
        children: [
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 26.w,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بيانات السائق والشاحنة',
                        style: GoogleFonts.cairo(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'ستُستخدم هذه البيانات لتتبع رحلاتك',
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
          SizedBox(height: 24.h),
          if (state.validationError != null || state.errorMessage != null)
            InlineErrorBanner(
              message: state.validationError ?? state.errorMessage!,
            ),
          _field(
            label: 'الاسم الأول',
            controller: _firstNameCtrl,
            icon: Icons.person_outline_rounded,
            onChanged: notifier.setFirstName,
          ),
          SizedBox(height: 14.h),
          _field(
            label: 'اسم العائلة',
            controller: _lastNameCtrl,
            icon: Icons.person_outline_rounded,
            onChanged: notifier.setLastName,
          ),
          SizedBox(height: 14.h),
          _field(
            label: 'رقم الهاتف',
            controller: _phoneCtrl,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            onChanged: notifier.setPhone,
          ),
          SizedBox(height: 14.h),
          _field(
            label: 'رقم لوحة الشاحنة',
            controller: _plateCtrl,
            icon: Icons.confirmation_number_outlined,
            onChanged: notifier.setTruckPlateNumber,
          ),
          SizedBox(height: 14.h),
          _field(
            label: 'رقم رخصة القيادة',
            controller: _licenseCtrl,
            icon: Icons.badge_outlined,
            onChanged: notifier.setLicenseNumber,
          ),
          SizedBox(height: 14.h),
          Text(
            'المنطقة المكلّف بها',
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          AreaDropdown(
            value: state.assignedArea,
            items: AppStrings.gazaAreas,
            onChanged: notifier.setAssignedArea,
          ),
          SizedBox(height: 14.h),
          _field(
            label: 'سعة الشاحنة (لتر)',
            controller: _capacityCtrl,
            icon: Icons.water_drop_outlined,
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                notifier.setTruckCapacity(double.tryParse(v) ?? 10000),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton.icon(
              onPressed: state.isSubmitting ? null : notifier.submit,
              icon: state.isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 22),
              label: Text(
                state.isSubmitting ? 'جارٍ الحفظ…' : 'تسجيل البيانات',
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )
              .animate(delay: 400.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                size: 20.w,
                color: AppColors.textMuted,
              ),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4.w, vertical: 14.h),
            ),
          ),
        ),
      ],
    );
  }
}
