import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../providers/connectivity_provider.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool _showOffline = false;
  bool _showRestored = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (previous, current) {
      if (previous == false && current == true) {
        setState(() {
          _showOffline = false;
          _showRestored = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showRestored = false);
        });
      } else if (current == false) {
        setState(() {
          _showOffline = true;
          _showRestored = false;
        });
      }
    });

    final showBanner = _showOffline || _showRestored;

    return Stack(
      children: [
        widget.child,
        if (showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _BannerStrip(isRestored: _showRestored),
          ),
      ],
    );
  }
}

class _BannerStrip extends StatelessWidget {
  final bool isRestored;

  const _BannerStrip({required this.isRestored});

  @override
  Widget build(BuildContext context) {
    final bgColor = isRestored ? AppColors.success : AppColors.danger;
    final icon = isRestored ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final message = isRestored
        ? 'عاد الاتصال بالإنترنت'
        : 'لا يوجد اتصال — وضع بدون إنترنت';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: bgColor,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4.h,
          bottom: 6.h,
          left: 14.w,
          right: 14.w,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14.w, color: Colors.white),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      )
          .animate()
          .slideY(begin: -1, end: 0, duration: 300.ms, curve: Curves.easeOut)
          .fadeIn(duration: 200.ms),
    );
  }
}
