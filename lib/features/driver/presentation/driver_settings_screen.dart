import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/driver_profile.dart';
import '../domain/repositories/driver_repository.dart';

/// Driver-only settings — logout plus personal profile, including the
/// profile picture.
///
/// The picture is stored as a plain URL on `drivers/{uid}.profilePictureUrl`
/// (see [DriverRepository.updateProfilePicture]). The natural way to fill
/// that field is an in-app camera/gallery picker uploading to Firebase
/// Storage — that needs the `image_picker` and `firebase_storage`
/// packages added to `pubspec.yaml`, which wasn't done in this pass since
/// it couldn't be resolved/verified without running `flutter pub get`
/// here. Until then this screen accepts a hosted image URL directly, so
/// the field and the org-management "driver photo" display are already
/// fully working end to end — only the *capture* step (camera/gallery)
/// is the follow-up.
class DriverSettingsScreen extends ConsumerStatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  ConsumerState<DriverSettingsScreen> createState() =>
      _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends ConsumerState<DriverSettingsScreen> {
  DriverProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) return;
    final result = await GetIt.I<DriverRepository>().getDriverProfile(uid);
    result.fold((_) {}, (profile) => setState(() => _profile = profile));
    setState(() => _loading = false);
  }

  Future<void> _editPictureUrl() async {
    final ctrl = TextEditingController(text: _profile?.profilePictureUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('رابط الصورة الشخصية', style: GoogleFonts.cairo()),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || _profile == null) return;

    await GetIt.I<DriverRepository>().updateProfilePicture(
      uid: _profile!.uid,
      downloadUrl: url,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'الملف الشخصي'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44.w,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: _profile?.profilePictureUrl != null
                            ? NetworkImage(_profile!.profilePictureUrl!)
                            : null,
                        child: _profile?.profilePictureUrl == null
                            ? Icon(Icons.person,
                                size: 44.w, color: AppColors.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _editPictureUrl,
                          child: CircleAvatar(
                            radius: 14.w,
                            backgroundColor: AppColors.primaryDark,
                            child: const Icon(Icons.edit,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                if (_profile != null) ...[
                  _infoTile('الاسم', _profile!.fullName),
                  _infoTile('الهاتف', _profile!.phone),
                  _infoTile('رقم لوحة الشاحنة', _profile!.truckPlateNumber),
                  _infoTile('رقم الرخصة', _profile!.licenseNumber),
                  _infoTile('المنطقة المكلّف بها', _profile!.assignedArea),
                  _infoTile('الحالة', _profile!.isActive ? 'نشط' : 'موقوف'),
                ],
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.logout_rounded, color: AppColors.danger),
                    label: Text('تسجيل الخروج',
                        style: GoogleFonts.cairo(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      await GetIt.I<AuthRepository>().signOut();
                      if (context.mounted) context.go(RouteNames.login);
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

  Widget _infoTile(String label, String value) => Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 12.sp, color: AppColors.textMuted)),
            Text(value.isEmpty ? '—' : value,
                style: GoogleFonts.cairo(
                    fontSize: 13.sp, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
