import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../../shared/models/household_model.dart';
import 'providers/organization_providers.dart';

/// Read-only oversight of registered households — organization can view
/// profiles and area-level water-consumption context, but never edits a
/// household's personal data directly (matches the Firestore rule:
/// `households` update is resident-owner-only; organization has read +
/// delete only — see `firebase/firestore.rules`).
class OrgResidentManagementScreen extends ConsumerStatefulWidget {
  const OrgResidentManagementScreen({super.key});

  @override
  ConsumerState<OrgResidentManagementScreen> createState() =>
      _OrgResidentManagementScreenState();
}

class _OrgResidentManagementScreenState
    extends ConsumerState<OrgResidentManagementScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final householdsAsync = ref.watch(allHouseholdsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'إدارة السكان'),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو المنطقة...',
                hintStyle: GoogleFonts.cairo(fontSize: 13.sp),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: householdsAsync.when(
              data: (households) {
                final filtered = _query.isEmpty
                    ? households
                    : households
                        .where((h) =>
                            h.familyName.contains(_query) ||
                            h.areaName.contains(_query))
                        .toList()
                  ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

                if (households.isEmpty) {
                  return Center(
                    child: Text('لا توجد أسر مسجّلة بعد',
                        style: GoogleFonts.cairo(color: AppColors.textMuted)),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text('لا توجد نتائج مطابقة',
                        style: GoogleFonts.cairo(color: AppColors.textMuted)),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) => _HouseholdCard(
                    household: filtered[i],
                    onTap: () => _showDetail(context, filtered[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('تعذّر تحميل بيانات الأسر',
                    style: GoogleFonts.cairo(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, HouseholdModel h) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HouseholdDetailSheet(household: h),
    );
  }
}

class _HouseholdCard extends StatelessWidget {
  final HouseholdModel household;
  final VoidCallback onTap;

  const _HouseholdCard({required this.household, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          child: Icon(Icons.home_outlined, color: AppColors.success),
        ),
        title: Text(
            household.familyName.isEmpty ? 'بدون اسم' : household.familyName,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, fontSize: 14.sp)),
        subtitle: Text(
          '${household.areaName} · ${household.householdSize} أفراد',
          style: GoogleFonts.cairo(fontSize: 11.sp, color: AppColors.textMuted),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('أولوية ${household.priorityScore}',
              style:
                  GoogleFonts.cairo(fontSize: 10.sp, color: AppColors.warning)),
        ),
      ),
    );
  }
}

class _HouseholdDetailSheet extends ConsumerWidget {
  final HouseholdModel household;
  const _HouseholdDetailSheet({required this.household});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                household.familyName.isEmpty
                    ? 'بدون اسم'
                    : household.familyName,
                style: GoogleFonts.cairo(
                    fontSize: 16.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 12.h),
            _row('المنطقة', household.areaName),
            _row('عدد الأفراد', '${household.householdSize}'),
            _row('كبار سن؟', household.hasElderly ? 'نعم' : 'لا'),
            _row('حالات مرضية؟', household.hasSick ? 'نعم' : 'لا'),
            _row('أطفال؟', household.hasChildren ? 'نعم' : 'لا'),
            _row('أيام منذ آخر توصيل', '${household.daysSinceLastDelivery}'),
            _row('درجة الأولوية', '${household.priorityScore}'),
            SizedBox(height: 16.h),
            Divider(color: AppColors.bgSecondary),
            SizedBox(height: 8.h),
            Text('استهلاك المياه',
                style: GoogleFonts.cairo(
                    fontSize: 13.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 4.h),
            Text(
              'التوصيل يُسجَّل على مستوى المنطقة وليس لكل أسرة على حدة — '
              'الرقم أدناه يمثّل إجمالي ما وُزِّع في منطقة "${household.areaName}" خلال آخر تقرير، وليس استهلاك هذه الأسرة تحديدًا.',
              style: GoogleFonts.cairo(
                  fontSize: 11.sp, color: AppColors.textMuted),
            ),
            SizedBox(height: 8.h),
            _AreaConsumptionBadge(areaName: household.areaName),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: GoogleFonts.cairo(
                    fontSize: 12.sp, color: AppColors.textMuted)),
            Text(v,
                style: GoogleFonts.cairo(
                    fontSize: 12.sp, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _AreaConsumptionBadge extends ConsumerWidget {
  final String areaName;
  const _AreaConsumptionBadge({required this.areaName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(todayReportProvider);
    final liters = reportAsync.valueOrNull?.litersByArea[areaName];

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.water_drop_outlined, color: AppColors.info, size: 18.w),
          SizedBox(width: 8.w),
          Text(
            liters != null
                ? '${liters.toStringAsFixed(0)} لتر لهذه المنطقة اليوم'
                : 'لا توجد بيانات توصيل لهذه المنطقة اليوم',
            style:
                GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
