import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../domain/entities/service_area.dart';
import '../domain/repositories/organization_repository.dart';
import 'providers/organization_providers.dart';

class OrgAreaManagementScreen extends ConsumerStatefulWidget {
  const OrgAreaManagementScreen({super.key});

  @override
  ConsumerState<OrgAreaManagementScreen> createState() =>
      _OrgAreaManagementScreenState();
}

class _OrgAreaManagementScreenState
    extends ConsumerState<OrgAreaManagementScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(allAreasProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'إدارة المناطق'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditSheet(context, null),
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('منطقة جديدة',
            style: GoogleFonts.cairo(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'بحث عن منطقة...',
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
            child: areasAsync.when(
              data: (areas) {
                final filtered = _query.isEmpty
                    ? areas
                    : areas.where((a) => a.name.contains(_query)).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      areas.isEmpty
                          ? 'لا توجد مناطق بعد'
                          : 'لا توجد نتائج مطابقة',
                      style: GoogleFonts.cairo(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 90.h),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) => _AreaCard(
                    area: filtered[i],
                    onEdit: () => _showEditSheet(context, filtered[i]),
                    onDelete: () => _confirmDelete(context, filtered[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('تعذّر تحميل المناطق',
                    style: GoogleFonts.cairo(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ServiceArea area) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('حذف المنطقة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        content: Text(
          area.assignedDriverUids.isEmpty
              ? 'هل تريد حذف "${area.name}"؟'
              : 'هذه المنطقة مرتبطة بـ ${area.assignedDriverUids.length} سائق. حذفها لن يلغِ تعيينهم تلقائيًا من ملفاتهم الشخصية. هل تريد المتابعة؟',
          style: GoogleFonts.cairo(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final result =
                  await GetIt.I<OrganizationRepository>().deleteArea(area.id);
              if (context.mounted) {
                result.fold(
                  (failure) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(failure.message),
                        backgroundColor: AppColors.danger),
                  ),
                  (_) {},
                );
              }
            },
            child: Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, ServiceArea? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final latCtrl = TextEditingController(
      text: (existing?.centerLat ?? 31.5018).toString(),
    );
    final lngCtrl = TextEditingController(
      text: (existing?.centerLng ?? 34.4668).toString(),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
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
              Text(
                existing == null ? 'منطقة جديدة' : 'تعديل المنطقة',
                style: GoogleFonts.cairo(
                    fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم المنطقة',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'خط العرض',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'خط الطول',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final lat = double.tryParse(latCtrl.text.trim()) ?? 31.5018;
                    final lng = double.tryParse(lngCtrl.text.trim()) ?? 34.4668;

                    final repo = GetIt.I<OrganizationRepository>();
                    final area = ServiceArea(
                      id: existing?.id ?? repo.newAreaId(),
                      name: name,
                      centerLat: lat,
                      centerLng: lng,
                      assignedDriverUids:
                          existing?.assignedDriverUids ?? const [],
                    );

                    final result = await repo.upsertArea(area);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    if (context.mounted) {
                      result.fold(
                        (failure) => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(failure.message),
                              backgroundColor: AppColors.danger),
                        ),
                        (_) {},
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('حفظ',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AreaCard extends StatelessWidget {
  final ServiceArea area;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AreaCard(
      {required this.area, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.map_outlined, color: AppColors.accent, size: 20.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(area.name,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700, fontSize: 14.sp)),
                Text(
                  '${area.assignedDriverUids.length} سائق مُعيَّن · ${area.centerLat.toStringAsFixed(3)}, ${area.centerLng.toStringAsFixed(3)}',
                  style: GoogleFonts.cairo(
                      fontSize: 11.sp, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
