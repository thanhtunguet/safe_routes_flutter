import 'dart:math' hide Point;

import 'package:flutter/material.dart' hide Route;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:saferoute/models/route.dart';
import 'package:saferoute/models/way_point.dart';
import 'package:saferoute/services/route_service.dart';
import 'package:supa_carbon_icons/supa_carbon_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteDetailsScreen extends StatefulWidget {
  final Route route;

  const RouteDetailsScreen({
    super.key,
    required this.route,
  });

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};

  final Set<Polyline> _polylines = {};

  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.route.isFavorite ?? false;
    _setupMapElements();
  }

  void _setupMapElements() {
    // Clear existing markers and polylines
    _markers.clear();
    _polylines.clear();

    // Add markers for all points
    for (int i = 0; i < widget.route.points.length; i++) {
      final point = widget.route.points[i];
      final latLng = LatLng(point.latitude, point.longitude);

      _markers.add(
        Marker(
          markerId: MarkerId('point_$i'),
          position: latLng,
          infoWindow: InfoWindow(
            title: i == 0
                ? 'Start'
                : i == widget.route.points.length - 1
                    ? 'End'
                    : 'Point ${i + 1}',
          ),
        ),
      );
    }

    // Add polyline connecting all points
    if (widget.route.points.length > 1) {
      final List<LatLng> polylinePoints = widget.route.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_path'),
          points: polylinePoints,
          width: 5,
          color: Colors.blue,
        ),
      );
    }
  }

  void _toggleFavorite() async {
    try {
      // Create a new route with updated favorite status
      final updatedRoute = Route(
        name: widget.route.name,
        description: widget.route.description,
        points: widget.route.points,
        isFavorite: !_isFavorite,
      );

      // Save the updated route
      await RouteService.saveRoute(updatedRoute);

      setState(() {
        _isFavorite = !_isFavorite;
      });

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //         _isFavorite ? 'Added to favorites' : 'Removed from favorites'),
      //     duration: const Duration(seconds: 1),
      //   ),
      // );
      _showSnackbar(
        _isFavorite ? 'Added to favorites' : 'Removed from favorites',
      );
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //       content: Text('Error updating favorite status: ${e.toString()}')),
      // );
      _showSnackbar('Error updating favorite status: ${e.toString()}');
    }
  }

  void _fitMapToRoute() {
    if (_mapController == null || widget.route.points.isEmpty) return;

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

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    if (widget.route.points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 points for directions')),
      );
      return;
    }

    final startPoint = widget.route.points.first;
    final endPoint = widget.route.points.last;

    // Create a Google Maps URL for directions with walking mode
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
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Could not launch Google Maps')),
      // );
      _showSnackbar('Could not launch Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    widget.route.points.first.latitude,
                    widget.route.points.first.longitude,
                  ),
                  zoom: 14,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
                zoomControlsEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Fit map to show all points
                  Future.delayed(
                      const Duration(milliseconds: 300), _fitMapToRoute);
                },
              ),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Points: ${widget.route.points.length}'),
                        const SizedBox(height: 4),
                        Text(
                          'Distance: ${_calculateDistance(widget.route.points)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _fitMapToRoute,
                        icon: const Icon(Icons.map),
                        label: const Text('Fit to Route'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _openInGoogleMaps,
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
