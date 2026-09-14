import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../settings/providers/settings_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  void _checkFirstRun() async {
    // Wait for the first frame to render before checking to avoid go_router state issues
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final settingsStream = ref.read(appSettingsProvider.stream);
        final settings = await settingsStream.first;
        if (mounted) {
          if (settings.isFirstRun) {
            context.go('/welcome');
          } else {
            context.go('/'); 
          }
        }
      } catch (e) {
        if (mounted) {
          context.go('/'); // Fallback to home if something fails
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
