import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saferoute/models/route.dart';
import 'package:saferoute/services/route_service.dart';

// Route state notifier responsible for managing routes
class RouteNotifier extends StateNotifier<AsyncValue<List<Route>>> {
  RouteNotifier() : super(const AsyncValue.loading()) {
    loadAllRoutes();
  }

  Future<void> loadAllRoutes() async {
    state = const AsyncValue.loading();
    try {
      final routes = await RouteService.getAllRoutes();
      state = AsyncValue.data(routes);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> saveRoute(Route route) async {
    await RouteService.saveRoute(route);
    loadAllRoutes(); // Refresh the list after adding
  }

  Future<void> deleteRoute(String name) async {
    await RouteService.deleteRoute(name);
    loadAllRoutes(); // Refresh the list after deletion
  }

  Future<void> toggleFavorite(Route route) async {
    // Create a new route with updated favorite status
    final updatedRoute = Route(
      name: route.name,
      description: route.description,
      points: route.points,
      isFavorite: !(route.isFavorite ?? false),
    );

    // Save the updated route
    await RouteService.saveRoute(updatedRoute);
    loadAllRoutes(); // Refresh the list to reflect changes
  }
}

// The provider that will be used by the UI to access route state
final routeProvider =
    StateNotifierProvider<RouteNotifier, AsyncValue<List<Route>>>(
  (ref) => RouteNotifier(),
);
