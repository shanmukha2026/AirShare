// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'views/radar_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AirShareApp(),
    ),
  );
}

class AirShareApp extends StatelessWidget {
  const AirShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        useMaterial3: true,
        fontFamily: 'Roboto', // Premium modern typography fallback
      ),
      home: const RadarScreen(),
    );
  }
}
