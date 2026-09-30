import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'reports_screen.dart';
import 'students_admin_screen.dart';
import 'teachers_screen.dart';

/// هيكل لوحة المدير — شريط تنقل عصري:
/// المعلمون والطلاب (تبويبان: المعلمون | الطلاب) | التقارير
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  final _screens = const [
    TeachersScreen(),
    StudentsAdminScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.015),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.lineSoft)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppColors.primarySurface,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon:
                  Icon(Icons.groups_rounded, color: AppColors.primary),
              label: 'المعلمون',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon:
                  Icon(Icons.school_rounded, color: AppColors.primary),
              label: 'الطلاب',
            ),
            NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined_rounded),
              selectedIcon: Icon(Icons.insert_chart_rounded,
                  color: AppColors.primary),
              label: 'التقارير',
            ),
          ],
        ),
      ),
    );
  }
}
