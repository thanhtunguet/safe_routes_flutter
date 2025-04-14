import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:saferoute/pages/home_screen.dart';
import 'package:saferoute/services/route_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  await RouteService.init();

  runApp(
    const SafeRouteApp(),
  );
}

class SafeRouteApp extends StatelessWidget {
  const SafeRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SafeRoute',
      home: HomeScreen(),
    );
  }
}
