import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../auth/domain/repositories/auth_repository.dart';

/// Organization-only settings — deliberately does not reuse the resident
/// `SettingsScreen`. An organization account has no household profile,
/// no theme/notification-radius preferences tied to a household, and
/// must never see resident-only actions (delete household, etc.), so a
/// shared screen gated by role checks would be more error-prone than a
/// small dedicated one.
class OrgSettingsScreen extends StatelessWidget {
  const OrgSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = GetIt.I<AuthRepository>().currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'إعدادات المؤسسة'),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.apartment_rounded,
                    color: AppColors.primaryDark, size: 28.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حساب المؤسسة',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700, fontSize: 14.sp)),
                      Text(email,
                          style: GoogleFonts.cairo(
                              fontSize: 12.sp, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.logout_rounded, color: AppColors.danger),
              label: Text('تسجيل الخروج',
                  style: GoogleFonts.cairo(
                      color: AppColors.danger, fontWeight: FontWeight.w700)),
              onPressed: () async {
                await GetIt.I<AuthRepository>().signOut();
                if (context.mounted) context.go(RouteNames.orgLogin);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.danger),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
