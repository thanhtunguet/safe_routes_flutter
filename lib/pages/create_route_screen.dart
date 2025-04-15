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

class CreateRouteScreen extends ConsumerWidget {
  const CreateRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state
    final state = ref.watch(routeCreationProvider);
    final nameController = TextEditingController(text: state.name);
    final descriptionController =
        TextEditingController(text: state.description);

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

    // Save route function
    Future<void> saveRoute() async {
      if (nameController.text.trim().isEmpty) {
        ref
            .read(toastProvider.notifier)
            .showError(context, 'Route name is required');
        return;
      }

      if (state.selectedPoints.length < 2) {
        ref
            .read(toastProvider.notifier)
            .showError(context, 'At least 2 points are required for a route');
        return;
      }

      final success =
          await ref.read(routeCreationProvider.notifier).saveRoute();

      if (!context.mounted) return;

      if (success) {
        ref
            .read(toastProvider.notifier)
            .showSuccess(context, 'Route saved successfully!');
        Navigator.pop(context, true);
      } else {
        ref
            .read(toastProvider.notifier)
            .showError(context, 'Error saving route');
      }
    }

    // Import route from QR code
    void importFromQrCode() async {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );

      if (!context.mounted) return;

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

          ref
              .read(toastProvider.notifier)
              .showSuccess(context, 'Route imported successfully!');
        } catch (e) {
          ref
              .read(toastProvider.notifier)
              .showError(context, 'Error importing route: ${e.toString()}');
        }
      }
    }

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
        ref.read(routeCreationProvider.notifier).setMapController(controller);
      },
      onTap: (latLng) {
        ref.read(routeCreationProvider.notifier).addPoint(latLng);
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
        ref
            .read(routeCreationProvider.notifier)
            .setAppleMapController(controller);
      },
      onTap: (point) {
        final latLng = LatLng(point.latitude, point.longitude);
        ref.read(routeCreationProvider.notifier).addPoint(latLng);
      },
      initialCameraPosition:
          (state.hasPermissionReady && state.currentLocation != null)
              ? apple_maps.CameraPosition(
                  target: apple_maps.LatLng(
                    state.currentLocation!.latitude,
                    state.currentLocation!.longitude,
                  ),
                  zoom: 14.0,
                )
              : const apple_maps.CameraPosition(
                  target: apple_maps.LatLng(20.9834277, 105.8187993),
                  zoom: 2.0,
                ),
    );
  }
}
