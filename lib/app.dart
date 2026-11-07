import 'package:flutter/material.dart';

import 'core/providers/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_navigation.dart';

class PencatatKeuanganApp extends StatelessWidget {
  const PencatatKeuanganApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (_, mode, __) => MaterialApp(
        title: 'Catat Keuangan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: const MainNavigation(),
      ),
    );
  }
}
