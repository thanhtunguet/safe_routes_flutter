import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saferoute/providers/route_provider.dart';
import 'package:saferoute/providers/toast_provider.dart';

/// This file exports all providers for easy access throughout the app
///
/// Usage:
/// ```dart
/// import 'package:saferoute/providers/providers.dart';
/// ```

// Re-export all providers
export 'route_creation_provider.dart';
export 'route_provider.dart';
export 'toast_provider.dart';

// App-wide providers configuration
final appProvidersContainer = ProviderContainer(
  overrides: [],
);

// Initialize all providers
Future<void> initializeProviders() async {
  // Force providers to initialize
  appProvidersContainer.read(routeProvider);
  appProvidersContainer.read(toastProvider);
}
