// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_provider.dart';
import 'views/splash_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AirShareApp(),
    ),
  );
}

class AirShareApp extends ConsumerWidget {
  const AirShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'AirShare',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // Dark theme — cyberpunk style
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.cyan,
          secondary: Colors.cyanAccent,
          surface: const Color(0xFF1E2830),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F171E),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardColor: const Color(0xFF1E2830),
        dividerColor: const Color(0xFF26323E),
      ),

      // Light theme — clean professional
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0077A8),
          secondary: const Color(0xFF00BCD4),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardColor: Colors.white,
        dividerColor: const Color(0xFFDDE3EA),
      ),

      home: const SplashScreen(),
    );
  }
}
