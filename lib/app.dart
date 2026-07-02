import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/database/providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'routing/app_router.dart';

/// Splash screen holati
final splashCompleteProvider = StateProvider<bool>((ref) => false);

class LugatchiApp extends ConsumerWidget {
  const LugatchiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final splashDone = ref.watch(splashCompleteProvider);
    final onboardingDone = ref.watch(onboardingCompleteProvider);

    return MaterialApp.router(
      title: "Lug'atchi",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        // Matn o'lchamini global qo'llash
        final mediaQuery = MediaQuery.of(context);
        final scaledChild = MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child!,
        );

        // Avval splash screen ko'rsatiladi
        if (!splashDone) {
          return SplashScreen(
            onComplete: () {
              ref.read(splashCompleteProvider.notifier).state = true;
            },
          );
        }

        return onboardingDone.when(
          data: (done) {
            if (!done) {
              return OnboardingScreen(
                onComplete: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_complete', true);
                  ref.invalidate(onboardingCompleteProvider);
                },
              );
            }
            return scaledChild;
          },
          loading: () => scaledChild,
          error: (_, _) => scaledChild,
        );
      },
    );
  }
}
