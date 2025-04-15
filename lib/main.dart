import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:saferoute/pages/home_screen.dart';
import 'package:saferoute/providers/providers.dart';
import 'package:saferoute/services/route_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize route service
  await RouteService.init();

  // Initialize providers
  await initializeProviders();

  runApp(
    const ProviderScope(
      child: SafeRouteApp(),
    ),
  );
}

class SafeRouteApp extends StatelessWidget {
  const SafeRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeRoute',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      // No need for special builder for toastification v1.0.0
      // Toastification will be handled by the provider directly
    );
  }
}
