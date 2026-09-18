import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/vault/presentation/meal_vault_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/welcome/presentation/splash_screen.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../localization/app_strings.dart';
import '../navigation/nav_lifecycle.dart';
import '../theme/app_palette.dart';
import '../widgets/app_icons.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _shellNavigatorHome = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorVault = GlobalKey<NavigatorState>(debugLabel: 'shellVault');
final _shellNavigatorHistory = GlobalKey<NavigatorState>(debugLabel: 'shellHistory');
final _shellNavigatorSettings = GlobalKey<NavigatorState>(debugLabel: 'shellSettings');

final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-runs `redirect` whenever the setup state loads/changes, so deep
  // links can't bypass the welcome gate on a cold start.
  final setupRefresh = ValueNotifier<int>(0);
  ref.onDispose(setupRefresh.dispose);
  ref.listen(appSettingsProvider, (_, __) => setupRefresh.value++);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: setupRefresh,
    redirect: (context, state) {
      final location = state.uri.path;
      // Splash is the bootstrap: it reads settings itself and navigates.
      if (location == '/splash') return null;
      final settings = ref.read(appSettingsProvider).valueOrNull;
      // Still loading (or failed): don't force anything, let splash decide.
      if (settings == null) return null;
      if (settings.isFirstRun && location != '/welcome') return '/welcome';
      if (!settings.isFirstRun && location == '/welcome') return '/';
      return null;
    },
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
                routes: [
                  GoRoute(
                    path: 'notifications',
                    name: 'notifications',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: NotificationsScreen(),
                    ),
                  ),
                ],
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
  int? _publishedBranch;

  /// Publishes the visible branch so Home/History/Settings can reset their
  /// UI-only state on re-entry. Called outside of `build` (gesture callback),
  /// therefore it may write to the provider synchronously.
  void _publishBranch(int index) {
    _publishedBranch = index;
    if (!mounted) return;
    if (ref.read(activeNavBranchProvider) == index) return;
    ref.read(activeNavBranchProvider.notifier).state = index;
  }

  /// Deep links (e.g. `context.go('/vault')` from the Home empty state) bypass
  /// `_onTap`, so the shell also re-publishes whatever branch it ends up on.
  /// Writing a provider during `build` is illegal, hence the post-frame hop.
  void _scheduleBranchSync(int index) {
    if (_publishedBranch == index) return;
    _publishedBranch = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(activeNavBranchProvider) != index) {
        ref.read(activeNavBranchProvider.notifier).state = index;
      }
    });
  }

  void _onTap(int index) {
    // Guard rapid 30ms switching (test 5.1): defer and drop overlapping frames
    if (_navLock) return;
    _navLock = true;
    try {
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
      _publishBranch(index);
    } catch (_) {
      // GoRouter may throw if shell is mid-transition during rapid taps — swallow
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navLock = false;
      });
      // Fallback release in case no frame is scheduled (e.g. tests pumping manually)
      Future.delayed(const Duration(milliseconds: 32), () {
        if (mounted) _navLock = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings(locale);
    _scheduleBranchSync(widget.navigationShell.currentIndex);

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
            height: 54,
            child: Directionality(
              // Mockups place the Home tab leftmost in both locales.
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _NavBarItem(
                    key: const ValueKey('nav_destination_home'),
                    iconData: Icons.home_rounded,
                    label: strings.navHome,
                    isSelected: widget.navigationShell.currentIndex == 0,
                    onTap: () => _onTap(0),
                  ),
                  _NavBarItem(
                    key: const ValueKey('nav_destination_vault'),
                    assetPath: 'assets/icons/nav_vault.png',
                    iconSize: 23.4,
                    label: strings.navVault,
                    isSelected: widget.navigationShell.currentIndex == 1,
                    onTap: () => _onTap(1),
                  ),
                  _NavBarItem(
                    key: const ValueKey('nav_destination_history'),
                    iconData: Icons.check_circle_outline_rounded,
                    label: strings.navHistory,
                    isSelected: widget.navigationShell.currentIndex == 2,
                    onTap: () => _onTap(2),
                  ),
                  _NavBarItem(
                    key: const ValueKey('nav_destination_settings'),
                    iconData: Icons.settings_rounded,
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
  final AppGlyph? glyph;
  final String? assetPath;
  final IconData? iconData;
  final double iconSize;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    super.key,
    this.glyph,
    this.assetPath,
    this.iconData,
    this.iconSize = 27.6,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : assert(glyph != null || assetPath != null || iconData != null);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = isSelected
        ? AppPalette.brandGreen
        : AppPalette.navIdle(brightness);

    final Widget iconWidget;
    if (assetPath != null) {
      iconWidget = ImageIcon(
        AssetImage(assetPath!),
        color: color,
        size: iconSize,
      );
    } else if (iconData != null) {
      iconWidget = Icon(
        iconData,
        color: color,
        size: iconSize,
      );
    } else {
      iconWidget = AppIcon(glyph!, color: color, size: iconSize);
    }

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 1.5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 1.5),
            // The green underline indicator
            Container(
              height: 2.5,
              width: 22,
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
