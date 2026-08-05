import 'package:flutter/material.dart';

import '../localization/arabic_text.dart';
import 'app_routes.dart';
import 'app_theme.dart';

class DistributionLoadRegisterApp extends StatelessWidget {
  const DistributionLoadRegisterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ArabicText.appName,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
