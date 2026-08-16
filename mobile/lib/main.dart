import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'providers/user_provider.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local persistent storage
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const ImpulseApp(),
    ),
  );
}

class ImpulseApp extends ConsumerWidget {
  const ImpulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return MaterialApp(
      title: 'Impulse — Fake Shopping Simulator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home:
          user.isOnboarded ? const MainNavigationScreen() : const LoginScreen(),
    );
  }
}
