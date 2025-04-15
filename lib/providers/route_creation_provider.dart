import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_maps;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saferoute/models/route.dart' as model;
import 'package:saferoute/models/way_point.dart' as model;
import 'package:saferoute/providers/route_provider.dart';

// State for the route creation screen
class RouteCreationState {
  final String name;
  final String description;
  final bool isFavorite;
  final bool hasPermissionReady;
  final LatLng? currentLocation;
  final List<LatLng> selectedPoints;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool isSaving;

  RouteCreationState({
    this.name = '',
    this.description = '',
    this.isFavorite = false,
    this.hasPermissionReady = false,
    this.currentLocation,
    this.selectedPoints = const [],
    this.markers = const {},
    this.polylines = const {},
    this.isSaving = false,
  });

  RouteCreationState copyWith({
    String? name,
    String? description,
    bool? isFavorite,
    bool? hasPermissionReady,
    LatLng? currentLocation,
    List<LatLng>? selectedPoints,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    bool? isSaving,
  }) {
    return RouteCreationState(
      name: name ?? this.name,
      description: description ?? this.description,
      isFavorite: isFavorite ?? this.isFavorite,
      hasPermissionReady: hasPermissionReady ?? this.hasPermissionReady,
      currentLocation: currentLocation ?? this.currentLocation,
      selectedPoints: selectedPoints ?? this.selectedPoints,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

// Provider for managing route creation state
class RouteCreationNotifier extends StateNotifier<RouteCreationState> {
  final Ref ref;
  int _markerIdCounter = 0;
  GoogleMapController? _mapController;
  apple_maps.AppleMapController? _appleMapController;

  RouteCreationNotifier(this.ref) : super(RouteCreationState()) {
    _checkOrRequestLocationPermission();
  }

  // Check or request location permission
  Future<void> _checkOrRequestLocationPermission() async {
    // Check if location permission is granted
    final status = await Permission.location.status;
    if (status.isGranted) {
      state = state.copyWith(hasPermissionReady: true);
      await _getCurrentLocation();
    } else {
      // Request permission
      final result = await Permission.location.request();
      if (result.isGranted) {
        state = state.copyWith(hasPermissionReady: true);
        await _getCurrentLocation();
      }
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    if (state.hasPermissionReady) {
      final location = await Location().getLocation();
      state = state.copyWith(
          currentLocation: LatLng(location.latitude!, location.longitude!));
    }
  }

  // Set Google map controller
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (state.selectedPoints.length > 1) {
      _updatePolylines();
    }
  }

  // Set Apple map controller
  void setAppleMapController(apple_maps.AppleMapController controller) {
    _appleMapController = controller;
    if (state.selectedPoints.length > 1) {
      _updatePolylines();
    }
  }

  // Set route data (name, description, favorite status)
  void setRouteData({String? name, String? description, bool? isFavorite}) {
    state = state.copyWith(
      name: name ?? state.name,
      description: description ?? state.description,
      isFavorite: isFavorite ?? state.isFavorite,
    );
  }

  // Add a point when map is tapped
  void addPoint(LatLng latLng) {
    final newSelectedPoints = [...state.selectedPoints, latLng];
    final newMarkers = {...state.markers};

    // Create a marker for this point
    final markerId = MarkerId('point_$_markerIdCounter');
    _markerIdCounter++;

    final marker = Marker(
      markerId: markerId,
      position: latLng,
      infoWindow: InfoWindow(
        title: "Point ${newSelectedPoints.length}",
        snippet: "Tap to remove",
        onTap: () {
          removePoint(newSelectedPoints.indexOf(latLng));
        },
      ),
    );

    newMarkers.add(marker);

    state = state.copyWith(
      selectedPoints: newSelectedPoints,
      markers: newMarkers,
    );

    // Update polylines when adding a new point
    if (newSelectedPoints.length > 1) {
      _updatePolylines();
    }
  }

  // Remove a point from the route
  void removePoint(int index) {
    if (index >= 0 && index < state.selectedPoints.length) {
      final newSelectedPoints = [...state.selectedPoints];
      newSelectedPoints.removeAt(index);

      // Rebuild all markers to keep indices aligned
      final newMarkers = <Marker>{};
      _markerIdCounter = 0;

      for (var point in newSelectedPoints) {
        final markerId = MarkerId('point_$_markerIdCounter');
        _markerIdCounter++;

        final marker = Marker(
          markerId: markerId,
          position: point,
          infoWindow: InfoWindow(
            title: "Point ${newSelectedPoints.indexOf(point) + 1}",
            snippet: "Tap to remove",
            onTap: () {
              removePoint(newSelectedPoints.indexOf(point));
            },
          ),
        );

        newMarkers.add(marker);
      }

      state = state.copyWith(
        selectedPoints: newSelectedPoints,
        markers: newMarkers,
      );

      // Update polylines after removing a point
      _updatePolylines();
    }
  }

  // Clear all points
  void clearPoints() {
    _markerIdCounter = 0;
    state = state.copyWith(
      selectedPoints: [],
      markers: {},
      polylines: {},
    );
  }

  // Update polylines connecting the points
  void _updatePolylines() {
    final newPolylines = <Polyline>{};

    if (state.selectedPoints.length > 1) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route_path'),
          points: state.selectedPoints,
          width: 5,
          color: Colors.blue,
        ),
      );
    }

    state = state.copyWith(polylines: newPolylines);
  }

  // Import route from QR code data
  void importRouteFromQrData(String qrData, model.Route importedRoute) {
    // Clear existing points
    _markerIdCounter = 0;
    final newSelectedPoints = <LatLng>[];
    final newMarkers = <Marker>{};

    // Add points from imported route
    for (var point in importedRoute.points) {
      final latLng = LatLng(point.latitude, point.longitude);
      newSelectedPoints.add(latLng);

      final markerId = MarkerId('point_$_markerIdCounter');
      _markerIdCounter++;

      newMarkers.add(
        Marker(
          markerId: markerId,
          position: latLng,
          infoWindow: InfoWindow(
            title: "Point ${newSelectedPoints.length}",
            snippet: "Tap to remove",
            onTap: () {
              removePoint(newSelectedPoints.indexOf(latLng));
            },
          ),
        ),
      );
    }

    state = state.copyWith(
      name: "${importedRoute.name} (Copy)",
      description: importedRoute.description ?? '',
      isFavorite: importedRoute.isFavorite ?? false,
      selectedPoints: newSelectedPoints,
      markers: newMarkers,
    );

    // Update polylines
    if (newSelectedPoints.length > 1) {
      _updatePolylines();
    }

    // Center map on the route if map controller is available
    if ((state.selectedPoints.isNotEmpty) &&
        (_mapController != null || _appleMapController != null)) {
      _fitMapToRoute();
    }
  }

  // Fit map to show all points
  void _fitMapToRoute() {
    if (state.selectedPoints.isEmpty) return;

    // Calculate bounds
    double minLat = state.selectedPoints.first.latitude;
    double maxLat = state.selectedPoints.first.latitude;
    double minLng = state.selectedPoints.first.longitude;
    double maxLng = state.selectedPoints.first.longitude;

    for (var point in state.selectedPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add padding
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    } else if (_appleMapController != null) {
      final appleBounds = apple_maps.LatLngBounds(
        southwest: apple_maps.LatLng(minLat - 0.01, minLng - 0.01),
        northeast: apple_maps.LatLng(maxLat + 0.01, maxLng + 0.01),
      );

      _appleMapController!.animateCamera(
        apple_maps.CameraUpdate.newLatLngBounds(appleBounds, 50),
      );
    }
  }

  // Convert Google Maps LatLng to our model Point
  model.WayPoint _convertToModelPoint(LatLng latLng) {
    return model.WayPoint(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
  }

  // Save the route
  Future<bool> saveRoute() async {
    state = state.copyWith(isSaving: true);

    try {
      // Convert LatLng points to model.Point objects
      final modelPoints =
          state.selectedPoints.map(_convertToModelPoint).toList();

      // Create a Route object
      final route = model.Route(
        name: state.name.trim(),
        description: state.description.trim(),
        isFavorite: state.isFavorite,
        points: modelPoints,
      );

      // Save the route using route provider
      await ref.read(routeProvider.notifier).saveRoute(route);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return false;
    }
  }
}

// Provider to use in the UI
final routeCreationProvider =
    StateNotifierProvider<RouteCreationNotifier, RouteCreationState>(
  (ref) => RouteCreationNotifier(ref),
);
