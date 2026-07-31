import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../registration/presentation/providers/registration_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  late final TextEditingController _familyNameController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _familyNameController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await GetIt.I<SecureStorageService>().setOnboardingComplete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final notifier = ref.read(registrationProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<RegistrationFormState>(registrationProvider, (previous, next) {
      if (next.isSuccess) {
        GetIt.I<SecureStorageService>().setOnboardingComplete();
        context.go('/schedule');
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──
            Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  AppStrings.onboardingSkip,
                  style: GoogleFonts.cairo(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.family_restroom_rounded,
                    color: AppColors.primary,
                    title: "اسم العائلة",
                    subtitle:
                        "أدخل اسم العائلة التي سيتم عرضها في بيانات الحساب",
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: TextField(
                        controller: _familyNameController,
                        textInputAction: TextInputAction.next,
                        onChanged: (value) => notifier.setFamilyName(value),
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "مثال: عائلة أبو أحمد",
                          hintStyle: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(
                            Icons.family_restroom_rounded,
                            color: AppColors.primary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                        ),
                      ),
                    ),
                  ),
                  _OnboardingPage(
                    icon: Icons.location_on_rounded,
                    color: AppColors.primary,
                    title: "اختر منطقتك السكنية",
                    subtitle:
                        "حدد المنطقة التي تسكن فيها لتصلك بيانات توزيع المياه بشكل أدق",
                    child: _AreaDropdown(
                      value: state.selectedArea,
                      items: AppStrings.gazaAreas,
                      onChanged: notifier.setArea,
                    ),
                  ),
                  _OnboardingPage(
                    icon: Icons.people_alt_rounded,
                    color: AppColors.success,
                    title: "عدد أفراد الأسرة",
                    subtitle:
                        "حدد عدد أفراد أسرتك ليتم تقدير احتياج المياه بشكل أفضل",
                    child: _CounterWidget(
                      value: state.householdSize,
                      onDecrement: () =>
                          notifier.setHouseholdSize(state.householdSize - 1),
                      onIncrement: () =>
                          notifier.setHouseholdSize(state.householdSize + 1),
                    ),
                  ),
                  _OnboardingPage(
                    icon: Icons.checklist_rounded,
                    color: AppColors.accent,
                    title: "الأوضاع الخاصة",
                    subtitle:
                        "حدد الحالات الخاصة داخل الأسرة لإعطاء أولوية مناسبة عند التوزيع",
                    child: Column(
                      children: [
                        _SwitchTile(
                          icon: Icons.elderly_rounded,
                          title: 'كبار سن',
                          subtitle: 'وجود أفراد فوق 60 سنة',
                          value: state.hasElderly,
                          onChanged: (v) => notifier.setHasElderly(value: v),
                        ),
                        SizedBox(height: 8.h),
                        _SwitchTile(
                          icon: Icons.local_hospital_rounded,
                          title: 'مرضى',
                          subtitle: 'وجود أفراد بحاجة لرعاية صحية',
                          value: state.hasSick,
                          onChanged: (v) => notifier.setHasSick(value: v),
                          activeColor: AppColors.danger,
                        ),
                        SizedBox(height: 8.h),
                        _SwitchTile(
                          icon: Icons.child_care_rounded,
                          title: 'أطفال',
                          subtitle: 'وجود أطفال تحت 10 سنوات',
                          value: state.hasChildren,
                          onChanged: (v) => notifier.setHasChildren(value: v),
                          activeColor: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Global Error Banner for Onboarding Flow ──
            if (state.validationError != null || state.errorMessage != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: _ErrorBanner(
                  message: state.validationError ?? state.errorMessage!,
                ),
              ),

            // ── Bottom controls ──
            Padding(
              padding: EdgeInsets.fromLTRB(32.w, 10.h, 32.w, 40.h),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 30.h),
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: ElevatedButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              if (_page == 0 && !notifier.validateFamilyName()) {
                                return;
                              }
                              if (_page < 3) {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                notifier.submit();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _page < 3
                                  ? AppStrings.onboardingNext
                                  : AppStrings.regSubmit,
                              style: GoogleFonts.cairo(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        // A Column defaults to mainAxisSize.max, which — as the direct
        // child of a SingleChildScrollView — receives an unbounded
        // (infinite) height constraint. Sizing to that constraint (rather
        // than to its own content) is what produced the overlapping-card
        // rendering: children were positioned against a bogus computed
        // height instead of their actual stacked height. `min` sizes the
        // column to its content, which is also the only thing that makes
        // `mainAxisAlignment: center` (removed above) meaningful in a
        // scrollable in the first place.
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 40.h),
          Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60.w, color: color),
          )
              .animate()
              .scale(
                duration: 600.ms,
                curve: Curves.elasticOut,
                begin: const Offset(0.5, 0.5),
              )
              .fadeIn(duration: 400.ms),
          SizedBox(height: 40.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          SizedBox(height: 14.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
              height: 1.8,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
          SizedBox(height: 30.h),
          child,
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

class _AreaDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _AreaDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: colorScheme.surface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            color: colorScheme.onSurface,
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

class _CounterWidget extends StatelessWidget {
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  static const int _min = 1;
  static const int _max = 20;

  const _CounterWidget({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: value > _min ? onDecrement : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.primary,
            disabledColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: value < _max ? onIncrement : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: AppColors.primary,
            disabledColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            iconSize: 30,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: 0.06)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
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
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: colorScheme.onSurfaceVariant,
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

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

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
