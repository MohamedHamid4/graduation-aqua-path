import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'providers/registration_provider.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  late final TextEditingController _familyNameController;

  @override
  void initState() {
    super.initState();
    _familyNameController = TextEditingController();
    // Pre-fills the form with the household's existing data (if any) so
    // reopening this screen from Settings → "تعديل بيانات الأسرة" edits
    // the same record instead of the user re-entering everything blind.
    Future.microtask(
      () => ref.read(registrationProvider.notifier).loadExistingIfAny(),
    );
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final notifier = ref.read(registrationProvider.notifier);

    ref.listen<RegistrationFormState>(registrationProvider, (previous, next) {
      // Automatically populate controller when family name is loaded
      if (next.familyName != _familyNameController.text) {
        _familyNameController.text = next.familyName;
      }

      if (!next.isSuccess) return;

      // Reached via Settings → "تعديل بيانات الأسرة" (pushed on top of
      // the existing stack): pop back there instead of re-running the
      // first-time onboarding hop to the schedule screen.
      if (context.canPop()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            content: Text(
              'تم تحديث بيانات الأسرة بنجاح',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
        );
        context.pop();
        return;
      }

      context.go('/schedule');
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        // Reached both as a mandatory first-run step (context.go — nothing
        // to pop back to) and pushed from Settings → "تعديل بيانات الأسرة"
        // (something to pop to). A visible back arrow that silently does
        // nothing in the first case is worse than no arrow at all, so only
        // show it when there's somewhere for it to actually go.
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          AppStrings.regTitle,
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
          const _HeaderCard()
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.1, end: 0),
          SizedBox(height: 24.h),
          if (state.validationError != null || state.errorMessage != null)
            RegistrationErrorBanner(
              message: state.validationError ?? state.errorMessage!,
            ),
          _sectionLabel('اسم العائلة'),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: TextField(
              controller: _familyNameController,
              textInputAction: TextInputAction.next,
              onChanged: notifier.setFamilyName,
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'مثال: عائلة أبو أحمد',
                hintStyle: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  color: AppColors.textMuted,
                ),
                icon: const Icon(
                  Icons.family_restroom_rounded,
                  color: AppColors.primary,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          _sectionLabel(AppStrings.regAreaLabel),
          SizedBox(height: 8.h),
          RegistrationAreaDropdown(
            value: state.selectedArea,
            items: AppStrings.gazaAreas,
            onChanged: notifier.setArea,
          ),
          SizedBox(height: 20.h),
          _sectionLabel(AppStrings.regSizeLabel),
          SizedBox(height: 8.h),
          RegistrationCounterWidget(
            value: state.householdSize,
            onDecrement: () =>
                notifier.setHouseholdSize(state.householdSize - 1),
            onIncrement: () =>
                notifier.setHouseholdSize(state.householdSize + 1),
          ),
          SizedBox(height: 20.h),
          _sectionLabel(AppStrings.regVulnerabilityLabel),
          SizedBox(height: 8.h),
          RegistrationSwitchTile(
            icon: Icons.elderly_rounded,
            title: 'كبار سن',
            subtitle: 'وجود أفراد فوق 60 سنة',
            value: state.hasElderly,
            onChanged: (v) => notifier.setHasElderly(value: v),
          ),
          SizedBox(height: 8.h),
          RegistrationSwitchTile(
            icon: Icons.local_hospital_rounded,
            title: 'مرضى',
            subtitle: 'وجود أفراد بحاجة لرعاية صحية',
            value: state.hasSick,
            onChanged: (v) => notifier.setHasSick(value: v),
            activeColor: AppColors.danger,
          ),
          SizedBox(height: 8.h),
          RegistrationSwitchTile(
            icon: Icons.child_care_rounded,
            title: 'أطفال',
            subtitle: 'وجود أطفال تحت 10 سنوات',
            value: state.hasChildren,
            onChanged: (v) => notifier.setHasChildren(value: v),
            activeColor: AppColors.accent,
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
                state.isSubmitting ? 'جارٍ الحفظ…' : AppStrings.regSubmit,
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
              .animate(delay: 500.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.cairo(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class RegistrationErrorBanner extends StatelessWidget {
  final String message;

  const RegistrationErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18.w,
            color: AppColors.danger,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Icon(Icons.home_rounded, color: Colors.white, size: 26.w),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.regHeaderTitle,
                  style: GoogleFonts.cairo(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  AppStrings.regHeaderSubtitle,
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
    );
  }
}

class RegistrationAreaDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const RegistrationAreaDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.bgCard,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: items
              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class RegistrationCounterWidget extends StatelessWidget {
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  static const int _min = 1;
  static const int _max = 20;

  const RegistrationCounterWidget({
    super.key,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: value > _min ? onDecrement : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.primary,
            disabledColor: AppColors.textMuted,
            iconSize: 30,
          ),
          Column(
            children: [
              Text(
                '$value',
                style: GoogleFonts.cairo(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'فرد',
                style: GoogleFonts.cairo(
                  fontSize: 12.sp,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: value < _max ? onIncrement : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: AppColors.primary,
            disabledColor: AppColors.textMuted,
            iconSize: 30,
          ),
        ],
      ),
    );
  }
}

class RegistrationSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const RegistrationSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: value ? activeColor.withValues(alpha: 0.06) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.3)
              : AppColors.borderDefault,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: value ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: activeColor, size: 22.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
          ),
        ],
      ),
    );
  }
}
