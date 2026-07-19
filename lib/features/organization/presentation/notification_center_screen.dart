import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../domain/entities/org_notification.dart';
import '../domain/repositories/organization_repository.dart';
import 'providers/organization_providers.dart';

/// Compose + send-history for organization-authored notifications. The
/// actual push happens server-side (`onNotificationCreated` Cloud
/// Function reacting to the Firestore write this screen performs) — see
/// [OrgNotification] doc comment.
class OrgNotificationCenterScreen extends ConsumerWidget {
  const OrgNotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(notificationHistoryProvider);
    final areasAsync = ref.watch(allAreasProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'مركز الإشعارات'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showComposeSheet(
          context,
          areasAsync.valueOrNull?.map((a) => a.name).toList() ?? [],
        ),
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.campaign_outlined, color: Colors.white),
        label: Text('إشعار جديد',
            style: GoogleFonts.cairo(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: historyAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('لم تُرسَل أي إشعارات بعد',
                  style: GoogleFonts.cairo(color: AppColors.textMuted)),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 90.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _NotificationCard(notification: items[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('تعذّر تحميل سجل الإشعارات',
              style: GoogleFonts.cairo(color: AppColors.danger)),
        ),
      ),
    );
  }

  void _showComposeSheet(BuildContext context, List<String> areaNames) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String? selectedArea; // null == broadcast to all

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إشعار جديد',
                      style: GoogleFonts.cairo(
                          fontSize: 16.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'نص الإشعار',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  DropdownButtonFormField<String?>(
                    value: selectedArea,
                    decoration: const InputDecoration(
                      labelText: 'الجهة المستهدَفة',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('جميع المناطق')),
                      ...areaNames.map((a) =>
                          DropdownMenuItem<String?>(value: a, child: Text(a))),
                    ],
                    onChanged: (v) => setSheetState(() => selectedArea = v),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final body = bodyCtrl.text.trim();
                        if (title.isEmpty || body.isEmpty) return;

                        final notification = OrgNotification(
                          id: '',
                          title: title,
                          body: body,
                          areaName: selectedArea,
                          createdAt: DateTime.now(),
                        );

                        final result = await GetIt.I<OrganizationRepository>()
                            .sendNotification(notification);
                        if (sheetContext.mounted)
                          Navigator.of(sheetContext).pop();
                        if (context.mounted) {
                          result.fold(
                            (failure) =>
                                ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(failure.message),
                                backgroundColor: AppColors.danger,
                              ),
                            ),
                            (_) => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إرسال الإشعار')),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('إرسال',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final OrgNotification notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.campaign_outlined,
                color: AppColors.info, size: 18.w),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700, fontSize: 13.sp)),
                SizedBox(height: 2.h),
                Text(notification.body,
                    style: GoogleFonts.cairo(
                        fontSize: 12.sp, color: AppColors.textPrimary)),
                SizedBox(height: 4.h),
                Text(
                  '${notification.areaName ?? "جميع المناطق"} · ${DateFormat('yyyy/MM/dd HH:mm').format(notification.createdAt)}',
                  style: GoogleFonts.cairo(
                      fontSize: 10.sp, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
