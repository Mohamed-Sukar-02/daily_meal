import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/localization/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_providers.dart';
import 'core/services/notification_service.dart';
import 'core/services/avatar_service.dart';
import 'core/services/app_config_sync_service.dart';
import 'core/database/database_providers.dart';
import 'core/services/orphan_image_sweeper.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Photo-heavy UI (vault grid, home heroes, cloud images). The stock image
  // cache (1000 images / 100 MB) evicts decoded JPEGs while scrolling a large
  // vault — a 720px-wide decoded frame is ~2 MB, so ~50 photos already fill
  // it and scrolling back re-decodes (visible jank). Raise the budget to a
  // still Android-friendly 200 MB / 1200 images; every MealImage already
  // passes cacheWidth, so entries stay proportionally small.
  PaintingBinding.instance.imageCache
    ..maximumSize = 1200
    ..maximumSizeBytes = 200 << 20;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  await NotificationService.instance.init();

  AvatarService.instance.downloadAvatarsIfNeeded().catchError((e, st) {
    debugPrint('Avatar download warning (caught): $e\n$st');
  });

  runApp(
    const ProviderScope(
      child: DailyMealApp(),
    ),
  );
}

class DailyMealApp extends ConsumerStatefulWidget {
  const DailyMealApp({super.key});

  @override
  ConsumerState<DailyMealApp> createState() => _DailyMealAppState();
}

class _DailyMealAppState extends ConsumerState<DailyMealApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(appDatabaseProvider);
      // One-shot startup cleanup (plain async call, not a provider side effect).
      OrphanImageSweeper.sweepAtStartup(db);
      AppConfigSyncService.instance.init(db: db);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      // Task-switcher title follows the active locale.
      onGenerateTitle: (context) => AppStrings(locale).appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Single source of truth for the system-overlay style. Flutter only
        // updates the status-bar icons when an AnnotatedRegion sits under
        // the status bar, and screens without an AppBar (home, vault,
        // history, settings, welcome) never set one — so the icons used to
        // stay stuck on whatever the previous screen left behind (invisible
        // light icons on the light background). Deriving the style from the
        // *effective* theme brightness covers every screen by default and
        // re-applies instantly when the user switches light/dark.
        // Individual screens can still override locally (e.g. MealScreen's
        // dark hero keeps light icons via its own AnnotatedRegion).
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            // Android: icon color. Dark icons on the light theme, light
            // icons on the dark theme.
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            // iOS: brightness of the status-bar *background*, so the meaning
            // is inverted relative to the Android flag above.
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
