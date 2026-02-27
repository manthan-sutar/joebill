import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.isAdmin ?? false;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kDivider)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            elevation: 0,
            backgroundColor: Colors.transparent,
            onTap: (i) {
              if ((i == 1 || i == 2) && !isAdmin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin access required')),
                );
                return;
              }
              setState(() => _currentIndex = i);
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.table_bar_outlined),
                activeIcon: Icon(Icons.table_bar_rounded),
                label: 'Tabs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined,
                    color: isAdmin ? null : kTextMuted.withValues(alpha: 0.4)),
                activeIcon: const Icon(Icons.bar_chart_rounded),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined,
                    color: isAdmin ? null : kTextMuted.withValues(alpha: 0.4)),
                activeIcon: const Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
