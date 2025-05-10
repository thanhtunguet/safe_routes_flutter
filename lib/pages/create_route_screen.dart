import 'dart:convert';
import 'dart:io';

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_maps;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:saferoute/models/route.dart' as model;
import 'package:saferoute/pages/qr_scanner_screen.dart';
import 'package:saferoute/providers/route_creation_provider.dart';
import 'package:saferoute/providers/toast_provider.dart';

class CreateRouteScreen extends ConsumerStatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  ConsumerState<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends ConsumerState<CreateRouteScreen> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  GoogleMapController? _mapController;
  apple_maps.AppleMapController? _appleMapController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(routeCreationProvider);
    nameController = TextEditingController(text: state.name);
    descriptionController = TextEditingController(text: state.description);

    // Add listeners to update state when text changes
    nameController.addListener(() {
      ref
          .read(routeCreationProvider.notifier)
          .setRouteData(name: nameController.text);
    });

    descriptionController.addListener(() {
      ref
          .read(routeCreationProvider.notifier)
          .setRouteData(description: descriptionController.text);
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _appleMapController = null;
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // Fit map to show all points
  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

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

  // Save route function
  Future<void> saveRoute() async {
    if (nameController.text.trim().isEmpty) {
      if (!mounted) return;
      ref
          .read(toastProvider.notifier)
          .showError(context, 'Route name is required');
      return;
    }

    if (ref.read(routeCreationProvider).selectedPoints.length < 2) {
      if (!mounted) return;
      ref
          .read(toastProvider.notifier)
          .showError(context, 'At least 2 points are required for a route');
      return;
    }

    final success = await ref.read(routeCreationProvider.notifier).saveRoute();

    if (!mounted) return;

    if (success) {
      ref
          .read(toastProvider.notifier)
          .showSuccess(context, 'Route saved successfully!');
      Navigator.pop(context, true);
    } else {
      ref.read(toastProvider.notifier).showError(context, 'Error saving route');
    }
  }

  // Import route from QR code
  void importFromQrCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      try {
        // Parse the JSON data from QR code
        final jsonData = jsonDecode(result);
        final importedRoute = model.Route.fromJson(jsonData);

        // Update state with imported route
        ref
            .read(routeCreationProvider.notifier)
            .importRouteFromQrData(result, importedRoute);

        // Update controller values
        nameController.text = "${importedRoute.name} (Copy)";
        descriptionController.text = importedRoute.description ?? '';

        // Fit map to show imported route
        final points = importedRoute.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        _fitMapToRoute(points);

        ref
            .read(toastProvider.notifier)
            .showSuccess(context, 'Route imported successfully!');
      } catch (e) {
        if (!mounted) return;
        ref
            .read(toastProvider.notifier)
            .showError(context, 'Error importing route: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state
    final state = ref.watch(routeCreationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: importFromQrCode,
            tooltip: 'Import from QR Code',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Platform.isIOS
                      ? _buildAppleMap(state, ref)
                      : _buildGoogleMap(state, ref),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(204),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Tap on map to add points (${state.selectedPoints.length} selected)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Route Name',
                      hintText: 'Enter a name for your route',
                    ),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Add details about this route (optional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Favorite'),
              value: state.isFavorite,
              onChanged: (bool value) {
                ref
                    .read(routeCreationProvider.notifier)
                    .setRouteData(isFavorite: value);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: state.isSaving ? null : saveRoute,
                      child: state.isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Save Route'),
                    ),
                  ),
                  if (state.selectedPoints.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        ref.read(routeCreationProvider.notifier).clearPoints();
                      },
                      tooltip: 'Clear all points',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMap(dynamic state, WidgetRef ref) {
    return GoogleMap(
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      mapType: MapType.normal,
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
      markers: state.markers,
      polylines: state.polylines,
      onMapCreated: (controller) {
        setState(() {
          _mapController = controller;
        });
        if (state.selectedPoints.length > 1) {
          _fitMapToRoute(state.selectedPoints);
        }
      },
      onTap: (latLng) {
        ref.read(routeCreationProvider.notifier).addPoint(latLng);
        if (state.selectedPoints.length > 1) {
          _fitMapToRoute(state.selectedPoints);
        }
      },
      initialCameraPosition:
          (state.hasPermissionReady && state.currentLocation != null)
              ? CameraPosition(
                  target: state.currentLocation!,
                  zoom: 14.0,
                )
              : const CameraPosition(
                  target: LatLng(20.9834277, 105.8187993),
                  zoom: 2.0,
                ),
    );
  }

  Widget _buildAppleMap(dynamic state, WidgetRef ref) {
    // Convert Google markers to Apple markers
    final appleMarkers = <String, apple_maps.Annotation>{};
    for (final marker in state.markers) {
      final appleMarkerId = marker.markerId.value;
      appleMarkers[appleMarkerId] = apple_maps.Annotation(
        annotationId: apple_maps.AnnotationId(appleMarkerId),
        position: apple_maps.LatLng(
          marker.position.latitude,
          marker.position.longitude,
        ),
      );
    }

    // Convert Google polylines to Apple polylines
    final applePolylines = <String, apple_maps.Polyline>{};
    for (final polyline in state.polylines) {
      final applePolylineId = polyline.polylineId.value;
      final points = polyline.points
          .map((p) => apple_maps.LatLng(p.latitude, p.longitude))
          .toList();

      applePolylines[applePolylineId] = apple_maps.Polyline(
        polylineId: apple_maps.PolylineId(applePolylineId),
        points: points,
        width: polyline.width,
        color: polyline.color,
      );
    }

    return apple_maps.AppleMap(
      mapType: apple_maps.MapType.standard,
      rotateGesturesEnabled: true,
      myLocationButtonEnabled: true,
      myLocationEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      annotations: Set<apple_maps.Annotation>.of(appleMarkers.values),
      polylines: Set<apple_maps.Polyline>.of(applePolylines.values),
      onMapCreated: (controller) {
        setState(() {
          _appleMapController = controller;
        });
        if (state.selectedPoints.length > 1) {
          _fitMapToRoute(state.selectedPoints);
        }
      },
      onTap: (point) {
        final latLng = LatLng(point.latitude, point.longitude);
        ref.read(routeCreationProvider.notifier).addPoint(latLng);
        if (state.selectedPoints.length > 1) {
          _fitMapToRoute(state.selectedPoints);
        }
      },
      initialCameraPosition:
          (state.hasPermissionReady && state.currentLocation != null)
              ? apple_maps.CameraPosition(
                  target: apple_maps.LatLng(
                    state.currentLocation!.latitude,
                    state.currentLocation!.longitude,
                  ),
                  zoom: 16.0,
                )
              : const apple_maps.CameraPosition(
                  target: apple_maps.LatLng(20.9834277, 105.8187993),
                  zoom: 16.0,
                ),
    );
  }
}
