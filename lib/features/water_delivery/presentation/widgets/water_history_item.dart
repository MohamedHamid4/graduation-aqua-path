import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class WaterHistoryItem extends StatelessWidget {
  final String amount;
  final String date;
  final bool acknowledged;
  final bool acknowledging;
  final VoidCallback? onAcknowledge;

  const WaterHistoryItem({
    super.key,
    required this.amount,
    required this.date,
    this.acknowledged = false,
    this.acknowledging = false,
    this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: colorScheme.primary,
                  size: 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$amount لتر',
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    date,
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (acknowledged)
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 18.w),
                SizedBox(width: 4.w),
                Text(
                  'تم الاستلام',
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            )
          else
            TextButton(
              onPressed: acknowledging ? null : onAcknowledge,
              child: acknowledging
                  ? SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'تأكيد الاستلام',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
