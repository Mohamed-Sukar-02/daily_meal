import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/vault/presentation/meal_vault_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/welcome/presentation/splash_screen.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../localization/app_strings.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _shellNavigatorHome = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorVault = GlobalKey<NavigatorState>(debugLabel: 'shellVault');
final _shellNavigatorHistory = GlobalKey<NavigatorState>(debugLabel: 'shellHistory');
final _shellNavigatorSettings = GlobalKey<NavigatorState>(debugLabel: 'shellSettings');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: WelcomeScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home (الرئيسية)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHome,
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),

          // Branch 1: Vault (خزانة الأكلات)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorVault,
            routes: [
              GoRoute(
                path: '/vault',
                name: 'vault',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MealVaultScreen(),
                ),
              ),
            ],
          ),

          // Branch 2: History (السجل)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHistory,
            routes: [
              GoRoute(
                path: '/history',
                name: 'history',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HistoryScreen(),
                ),
              ),
            ],
          ),

          // Branch 3: Settings (الإعدادات)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettings,
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings(locale);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.navigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  key: const ValueKey('nav_destination_home'),
                  icon: Icons.home_rounded,
                  label: strings.navHome,
                  isSelected: navigationShell.currentIndex == 0,
                  onTap: () => _onTap(0),
                  theme: theme,
                ),
                _NavBarItem(
                  key: const ValueKey('nav_destination_vault'),
                  icon: Icons.storefront_outlined,
                  label: strings.navVault,
                  isSelected: navigationShell.currentIndex == 1,
                  onTap: () => _onTap(1),
                  theme: theme,
                ),
                _NavBarItem(
                  key: const ValueKey('nav_destination_history'),
                  icon: Icons.history, // Changed to clock-like history icon
                  label: strings.navHistory,
                  isSelected: navigationShell.currentIndex == 2,
                  onTap: () => _onTap(2),
                  theme: theme,
                ),
                _NavBarItem(
                  key: const ValueKey('nav_destination_settings'),
                  icon: Icons.settings,
                  label: strings.navSettings,
                  isSelected: navigationShell.currentIndex == 3,
                  onTap: () => _onTap(3),
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected 
        ? theme.colorScheme.primary 
        : theme.colorScheme.onSurfaceVariant;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            // The green underline indicator
            Container(
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
