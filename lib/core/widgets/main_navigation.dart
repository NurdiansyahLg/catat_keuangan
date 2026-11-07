import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/categories/screens/categories_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../constants/app_colors.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      DashboardScreen(
        onSeeAllTransactions: () => setState(() => _currentIndex = 1),
      ),
      const TransactionsScreen(),
      const ReportsScreen(),
      const CategoriesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            indicatorColor: AppColors.incomeContainer,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 22,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.surface(context),
            elevation: 0,
            animationDuration: const Duration(milliseconds: 250),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Transaksi',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: 'Laporan',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category_rounded),
                label: 'Kategori',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Pengaturan',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
