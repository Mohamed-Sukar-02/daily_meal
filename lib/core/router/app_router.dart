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
import '../theme/app_palette.dart';
import '../widgets/app_icons.dart';

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

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  bool _navLock = false;
  int? _pendingIndex;

  void _onTap(int index) {
    // Guard rapid 30ms switching (test 5.1): queue pending and defer to next frame
    // to avoid setState-during-build / shell mid-transition exceptions.
    if (_navLock) {
      _pendingIndex = index;
      return;
    }
    _navLock = true;
    // Defer actual navigation to post-frame so it never runs during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _navLock = false;
        return;
      }
      try {
        widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        );
      } catch (_) {
        // Swallow GoRouter shell transition errors during rapid taps
      }
      // Release lock on next frame and flush pending tap if any
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navLock = false;
        if (_pendingIndex != null) {
          final pending = _pendingIndex!;
          _pendingIndex = null;
          _onTap(pending);
        }
      });
      Future.delayed(const Duration(milliseconds: 32), () {
        if (!mounted) return;
        if (_navLock) {
          _navLock = false;
          if (_pendingIndex != null) {
            final pending = _pendingIndex!;
            _pendingIndex = null;
            _onTap(pending);
          }
        }
      });
    });
    // Ensure a frame is scheduled even in tests that use pump(Duration)
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings(locale);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppPalette.navBackground(theme.brightness),
          border: Border(
            top: BorderSide(
              color: AppPalette.hairline(theme.brightness),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Directionality(
              // Mockups place the Home tab leftmost in both locales.
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _NavBarItem(
                    key: const ValueKey('nav_destination_home'),
                    glyph: AppGlyph.home,
                    label: strings.navHome,
                    isSelected: widget.navigationShell.currentIndex == 0,
                    onTap: () => _onTap(0),
                  ),
                  _NavBarItem(
                    key: const ValueKey('nav_destination_vault'),
                    glyph: AppGlyph.vault,
                    label: strings.navVault,
                    isSelected: widget.navigationShell.currentIndex == 1,
                    onTap: () => _onTap(1),
                  ),
                  _NavBarItem(
                    key: const ValueKey('nav_destination_history'),
                    glyph: AppGlyph.history,
                    label: strings.navHistory,
                    isSelected: widget.navigationShell.currentIndex == 2,
                    onTap: () => _onTap(2),
                  ),
                  _NavBarItem(
                    key: const ValueKey('nav_destination_settings'),
                    glyph: AppGlyph.settings,
                    label: strings.navSettings,
                    isSelected: widget.navigationShell.currentIndex == 3,
                    onTap: () => _onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final AppGlyph glyph;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    super.key,
    required this.glyph,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = isSelected
        ? AppPalette.brandGreen
        : AppPalette.navIdle(brightness);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(glyph, color: color, size: 24),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // The green underline indicator
            Container(
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppPalette.brandGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
