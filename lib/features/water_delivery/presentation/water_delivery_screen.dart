import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/aqua_app_bar.dart';
import '../../../core/widgets/aqua_error_widget.dart';
import '../../../core/widgets/aqua_shimmer.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import 'package:get_it/get_it.dart';
import 'providers/water_delivery_provider.dart';
import 'widgets/water_history_item.dart';
import 'widgets/water_summary_card.dart';

/// Read-only delivery history for the resident's area. Quantities are
/// entered exclusively by the driver at the moment of delivery (see
/// `driver_delivery_provider.dart`) — a resident may only view the
/// history and optionally acknowledge receipt, never edit the amount.
class WaterDeliveryScreen extends ConsumerWidget {
  final String truckId;

  const WaterDeliveryScreen({super.key, required this.truckId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(areaWaterDeliveriesProvider);
    final totalAsync = ref.watch(areaWaterTotalProvider);
    final acknowledging = ref.watch(deliveryAcknowledgeProvider);
    final myUid = GetIt.I<AuthRepository>().currentUser?.uid;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const AquaAppBar(title: 'سجل استلام المياه'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 40.h),
        children: [
          totalAsync.when(
            data: (total) =>
                WaterSummaryCard(totalAmount: total.toStringAsFixed(0))
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
            loading: () => const AquaShimmer(height: 120),
            error: (_, __) => const SizedBox.shrink(),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18.w, color: colorScheme.onSecondaryContainer),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'يقوم السائق بتسجيل كمية المياه عند كل عملية توزيع. يمكنك تأكيد الاستلام بعد وصول الشحنة.',
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
          SizedBox(height: 24.h),
          Text(
            'سجل استلام المياه',
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ).animate(delay: 300.ms).fadeIn(),
          SizedBox(height: 12.h),
          historyAsync
              .when(
                data: (deliveries) {
                  if (deliveries.isEmpty) {
                    return const AquaErrorWidget.empty(
                      title: 'لا يوجد سجل حالياً',
                      message:
                          'ستظهر هنا عمليات التوزيع التي يسجلها السائق لمنطقتك',
                    );
                  }
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: deliveries.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: colorScheme.outlineVariant),
                      itemBuilder: (_, i) {
                        final d = deliveries[i];
                        final isAcked =
                            myUid != null && d.acknowledgedBy(myUid);
                        return WaterHistoryItem(
                          amount: d.amountLiters.toStringAsFixed(0),
                          date: _formatDate(d.createdAt),
                          acknowledged: isAcked,
                          acknowledging: acknowledging.contains(d.deliveryId),
                          onAcknowledge: () => ref
                              .read(deliveryAcknowledgeProvider.notifier)
                              .acknowledge(d.deliveryId),
                        );
                      },
                    ),
                  );
                },
                loading: () => const AquaShimmerList(count: 3),
                error: (e, _) => AquaErrorWidget.network(
                  onRetry: () => ref.invalidate(areaWaterDeliveriesProvider),
                ),
              )
              .animate(delay: 450.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff == 2) return 'قبل يومين';
    return DateFormat('yyyy/MM/dd').format(date);
  }
}
