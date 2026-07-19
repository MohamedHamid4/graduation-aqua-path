import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/connectivity_banner.dart';

class AquaPathApp extends ConsumerWidget {
  const AquaPathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) {
        return MaterialApp.router(
          title: 'AquaPath',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme, // white+green — the only theme
          routerConfig: router,
          locale: const Locale('ar', 'PS'),
          supportedLocales: const [
            Locale('ar', 'PS'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return ConnectivityBanner(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
