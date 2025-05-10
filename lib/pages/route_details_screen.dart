import 'dart:io' show Platform;
import 'dart:math' hide Point;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_maps;
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:saferoute/models/route.dart';
import 'package:saferoute/models/way_point.dart';
import 'package:saferoute/providers/route_provider.dart';
import 'package:saferoute/providers/toast_provider.dart';
import 'package:supa_carbon_icons/supa_carbon_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// Provider for the map state
final mapStateProvider =
    StateNotifierProvider.autoDispose.family<MapStateNotifier, MapState, Route>(
  (ref, route) => MapStateNotifier(route),
);

// Map state class
class MapState {
  final bool isFavorite;
  final Set<Marker> googleMarkers;
  final Set<Polyline> googlePolylines;
  final Set<apple_maps.Annotation> appleAnnotations;
  final Set<apple_maps.Polyline> applePolylines;

  MapState({
    required this.isFavorite,
    required this.googleMarkers,
    required this.googlePolylines,
    required this.appleAnnotations,
    required this.applePolylines,
  });

  MapState copyWith({
    bool? isFavorite,
    Set<Marker>? googleMarkers,
    Set<Polyline>? googlePolylines,
    Set<apple_maps.Annotation>? appleAnnotations,
    Set<apple_maps.Polyline>? applePolylines,
  }) {
    return MapState(
      isFavorite: isFavorite ?? this.isFavorite,
      googleMarkers: googleMarkers ?? this.googleMarkers,
      googlePolylines: googlePolylines ?? this.googlePolylines,
      appleAnnotations: appleAnnotations ?? this.appleAnnotations,
      applePolylines: applePolylines ?? this.applePolylines,
    );
  }
}

// Map state notifier
class MapStateNotifier extends StateNotifier<MapState> {
  final Route route;

  MapStateNotifier(this.route)
      : super(MapState(
          isFavorite: route.isFavorite ?? false,
          googleMarkers: {},
          googlePolylines: {},
          appleAnnotations: {},
          applePolylines: {},
        )) {
    setupMapElements();
  }

  GoogleMapController? googleMapController;
  apple_maps.AppleMapController? appleMapController;

  void setupMapElements() {
    if (Platform.isAndroid) {
      setupGoogleMapElements();
    } else if (Platform.isIOS) {
      setupAppleMapElements();
    }
  }

  void setupGoogleMapElements() {
    final Set<Marker> markers = {};
    final Set<Polyline> polylines = {};

    // Add markers for all points
    for (int i = 0; i < route.points.length; i++) {
      final point = route.points[i];
      final latLng = LatLng(point.latitude, point.longitude);

      markers.add(
        Marker(
          markerId: MarkerId('point_$i'),
          position: latLng,
          infoWindow: InfoWindow(
            title: i == 0
                ? 'Start'
                : i == route.points.length - 1
                    ? 'End'
                    : 'Point ${i + 1}',
          ),
        ),
      );
    }

    // Add polyline connecting all points
    if (route.points.length > 1) {
      final List<LatLng> polylinePoints = route.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      polylines.add(
        Polyline(
          polylineId: const PolylineId('route_path'),
          points: polylinePoints,
          width: 5,
          color: Colors.blue,
        ),
      );
    }

    state = state.copyWith(googleMarkers: markers, googlePolylines: polylines);
  }

  void setupAppleMapElements() {
    final Set<apple_maps.Annotation> annotations = {};
    final Set<apple_maps.Polyline> polylines = {};

    // Add annotations (markers) for all points
    for (int i = 0; i < route.points.length; i++) {
      final point = route.points[i];
      final coordinate = apple_maps.LatLng(point.latitude, point.longitude);

      annotations.add(
        apple_maps.Annotation(
          annotationId: apple_maps.AnnotationId('point_$i'),
          position: coordinate,
          infoWindow: apple_maps.InfoWindow(
            title: i == 0
                ? 'Start'
                : i == route.points.length - 1
                    ? 'End'
                    : 'Point ${i + 1}',
          ),
        ),
      );
    }

    // Add polyline connecting all points
    if (route.points.length > 1) {
      final List<apple_maps.LatLng> polylinePoints = route.points
          .map((point) => apple_maps.LatLng(point.latitude, point.longitude))
          .toList();

      polylines.add(
        apple_maps.Polyline(
          polylineId: apple_maps.PolylineId('route_path'),
          points: polylinePoints,
          width: 5,
          color: Colors.blue,
        ),
      );
    }

    state = state.copyWith(
        appleAnnotations: annotations, applePolylines: polylines);
  }

  // Add method to toggle favorite status
  void updateFavoriteStatus(bool isFavorite) {
    state = state.copyWith(isFavorite: isFavorite);
  }
}

class RouteDetailsScreen extends ConsumerStatefulWidget {
  final Route route;

  const RouteDetailsScreen({
    super.key,
    required this.route,
  });

  @override
  ConsumerState<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends ConsumerState<RouteDetailsScreen> {
  // Google Maps controller
  GoogleMapController? _googleMapController;
  // Apple Maps controller
  apple_maps.AppleMapController? _appleMapController;

  @override
  void initState() {
    super.initState();
  }

  void _toggleFavorite() async {
    try {
      await ref.read(routeProvider.notifier).toggleFavorite(widget.route);

      // Get the current state
      final mapState = ref.read(mapStateProvider(widget.route));
      final newIsFavorite = !mapState.isFavorite;

      // Update the local state using the notifier's method
      ref
          .read(mapStateProvider(widget.route).notifier)
          .updateFavoriteStatus(newIsFavorite);

      if (mounted) {
        ref.read(toastProvider.notifier).showSuccess(
              context,
              newIsFavorite ? 'Added to favorites' : 'Removed from favorites',
            );
      }
    } catch (e) {
      if (mounted) {
        ref.read(toastProvider.notifier).showError(
              context,
              'Error updating favorite status: ${e.toString()}',
            );
      }
    }
  }

  void _fitMapToRoute() {
    if (widget.route.points.isEmpty) return;

    if (Platform.isAndroid && _googleMapController != null) {
      _fitGoogleMapToRoute();
    } else if (Platform.isIOS && _appleMapController != null) {
      _fitAppleMapToRoute();
    }
  }

  void _fitGoogleMapToRoute() {
    if (_googleMapController == null || widget.route.points.isEmpty) return;

    final List<LatLng> points = widget.route.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    // Calculate bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add some padding
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _googleMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  void _fitAppleMapToRoute() {
    if (_appleMapController == null || widget.route.points.isEmpty) return;

    final List<apple_maps.LatLng> points = widget.route.points
        .map((point) => apple_maps.LatLng(point.latitude, point.longitude))
        .toList();

    // Calculate bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add some padding
    final apple_maps.LatLngBounds bounds = apple_maps.LatLngBounds(
      southwest: apple_maps.LatLng(minLat - 0.01, minLng - 0.01),
      northeast: apple_maps.LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _appleMapController!.animateCamera(
      apple_maps.CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  Future<void> _openInMaps() async {
    if (widget.route.points.length < 2) {
      ref
          .read(toastProvider.notifier)
          .showWarning(context, 'Need at least 2 points for directions');
      return;
    }

    final startPoint = widget.route.points.first;
    final endPoint = widget.route.points.last;

    // Always use Google Maps
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${startPoint.latitude},${startPoint.longitude}'
        '&destination=${endPoint.latitude},${endPoint.longitude}'
        '&travelmode=walking';

    // Add waypoints if there are intermediate points
    if (widget.route.points.length > 2) {
      final waypoints =
          widget.route.points.sublist(1, widget.route.points.length - 1);
      final waypointsString = waypoints
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');

      final urlWithWaypoints = '$url&waypoints=$waypointsString';
      await _launchUrl(urlWithWaypoints);
    } else {
      await _launchUrl(url);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ref
            .read(toastProvider.notifier)
            .showError(context, 'Could not launch maps application');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapStateProvider(widget.route));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        actions: [
          IconButton(
            icon: Icon(
                mapState.isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFavorite,
            tooltip: mapState.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Platform.isAndroid
                  ? _buildGoogleMap(mapState)
                  : Platform.isIOS
                      ? _buildAppleMap(mapState)
                      : const Center(
                          child: Text('Maps not supported on this platform')),
            ),
            if (widget.route.description != null &&
                widget.route.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.route.description!),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Points: ${widget.route.points.length}'),
                      Text(
                        'Distance: ${_calculateDistance(widget.route.points)} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _fitMapToRoute,
                          icon: const Icon(Icons.map),
                          label: const Text('Fit to Route'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openInMaps,
                          icon: Icon(
                            CarbonIcons.map,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          label: const Text('Navigate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMap(MapState mapState) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          widget.route.points.first.latitude,
          widget.route.points.first.longitude,
        ),
        zoom: 14,
      ),
      markers: mapState.googleMarkers,
      polylines: mapState.googlePolylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapType: MapType.normal,
      zoomControlsEnabled: true,
      onMapCreated: (controller) {
        _googleMapController = controller;
        if (mounted) {
          ref
              .read(mapStateProvider(widget.route).notifier)
              .googleMapController = controller;
        }
        // Fit map to show all points
        Future.delayed(const Duration(milliseconds: 300), _fitMapToRoute);
      },
    );
  }

  Widget _buildAppleMap(MapState mapState) {
    return apple_maps.AppleMap(
      initialCameraPosition: apple_maps.CameraPosition(
        target: apple_maps.LatLng(
          widget.route.points.first.latitude,
          widget.route.points.first.longitude,
        ),
        zoom: 14,
      ),
      annotations: mapState.appleAnnotations,
      polylines: mapState.applePolylines,
      onMapCreated: (controller) {
        _appleMapController = controller;
        ref.read(mapStateProvider(widget.route).notifier).appleMapController =
            controller;
        // Fit map to show all points
        Future.delayed(const Duration(milliseconds: 300), _fitMapToRoute);
      },
    );
  }

  String _calculateDistance(List<WayPoint> points) {
    // Simple implementation - in a real app you would use the haversine formula
    // or a mapping service to calculate actual route distance
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      // Very rough approximation for demo purposes
      final latDiff = (p2.latitude - p1.latitude).abs();
      final lngDiff = (p2.longitude - p1.longitude).abs();

      // 111.2 km is approximately 1 degree at the equator
      final distance = 111.2 * sqrt(latDiff * latDiff + lngDiff * lngDiff);
      totalDistance += distance;
    }

    return totalDistance.toStringAsFixed(2);
  }
}
