import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:saferoute/models/route.dart' as model;
import 'package:saferoute/models/way_point.dart' as model;
import 'package:saferoute/services/route_service.dart';

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isFavorite = false;
  bool _hasPermissionReady = false;
  LatLng? _currentLocation;

  // Variables for managing route points
  final List<LatLng> _selectedPoints = [];
  final Set<Marker> _markers = {};
  int _markerIdCounter = 0;
  GoogleMapController? _mapController;
  bool _isSaving = false;

  // Store the polyline
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _checkOrRequestLocationPermission();
  }

  @override
  dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  _checkOrRequestLocationPermission() async {
    // Check if location permission is granted
    final status = await Permission.location.status;
    if (status.isGranted) {
      setState(() {
        _hasPermissionReady = true;
      });
    } else {
      // Request permission
      final result = await Permission.location.request();
      if (result.isGranted) {
        setState(() {
          _hasPermissionReady = true;
        });

        // Get current location
        final location = await Location().getLocation();
        setState(() {
          _currentLocation = LatLng(location.latitude!, location.longitude!);
        });
        _showSnackbar('Location permission granted and location retrieved.');
      } else {
        _showSnackbar('Location permission denied');
      }
    }
  }

  _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Convert Google Maps LatLng to our model Point
  model.WayPoint _convertToModelPoint(LatLng latLng) {
    return model.WayPoint(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
  }

  // Add a point when map is tapped
  void _addPoint(LatLng latLng) {
    setState(() {
      _selectedPoints.add(latLng);

      // Create a marker for this point
      final markerId = MarkerId('point_$_markerIdCounter');
      _markerIdCounter++;

      final marker = Marker(
        markerId: markerId,
        position: latLng,
        infoWindow: InfoWindow(
          title: "Point ${_selectedPoints.length}",
          snippet: "Tap to remove",
          onTap: () {
            _removePoint(_selectedPoints.indexOf(latLng));
          },
        ),
      );

      _markers.add(marker);

      // Update polylines when adding a new point
      if (_selectedPoints.length > 1) {
        _updatePolylines();
      }
    });
  }

  // Remove a point from the route
  void _removePoint(int index) {
    if (index >= 0 && index < _selectedPoints.length) {
      setState(() {
        _selectedPoints.removeAt(index);

        // Rebuild all markers to keep indices aligned
        _markers.clear();
        _markerIdCounter = 0;

        for (var point in _selectedPoints) {
          final markerId = MarkerId('point_$_markerIdCounter');
          _markerIdCounter++;

          final marker = Marker(
            markerId: markerId,
            position: point,
            infoWindow: InfoWindow(
              title: "Point ${_selectedPoints.indexOf(point) + 1}",
              snippet: "Tap to remove",
              onTap: () {
                _removePoint(_selectedPoints.indexOf(point));
              },
            ),
          );

          _markers.add(marker);
        }

        // Update polylines after removing a point
        _updatePolylines();
      });
    }
  }

  // Save the route using RouteService
  Future<void> _saveRoute() async {
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      _showSnackbar('Route name is required');
      return;
    }

    if (_selectedPoints.length < 2) {
      _showSnackbar('At least 2 points are required for a route');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Convert LatLng points to model.Point objects
      final modelPoints = _selectedPoints.map(_convertToModelPoint).toList();

      // Create a Route object
      final route = model.Route(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isFavorite: _isFavorite,
        points: modelPoints,
      );

      // Save the route using RouteService
      await RouteService.saveRoute(route);

      _showSnackbar('Route saved successfully!');
      // Navigator.pop(context, true); // Return success to previous screen
      _popWithBool(true);
    } catch (e) {
      _showSnackbar('Error saving route: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  _popWithBool(bool value) {
    Navigator.pop(context, value);
  }

  // Draw a polyline connecting the points
  void _updatePolylines() {
    _polylines.clear();

    if (_selectedPoints.length > 1) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_path'),
          points: _selectedPoints,
          width: 5,
          color: Colors.blue,
        ),
      );
    }
  }

  // Import route from QR code
  void _importFromQrCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (result != null) {
      try {
        // Parse the JSON data from QR code
        final jsonData = jsonDecode(result);
        final importedRoute = model.Route.fromJson(jsonData);

        // Update the UI with imported data
        setState(() {
          // Update form fields
          _nameController.text = "${importedRoute.name} (Copy)";
          _descriptionController.text = importedRoute.description ?? '';
          _isFavorite = importedRoute.isFavorite ?? false;

          // Clear existing points
          _selectedPoints.clear();
          _markers.clear();
          _polylines.clear();
          _markerIdCounter = 0;

          // Add points from imported route
          for (var point in importedRoute.points) {
            final latLng = LatLng(point.latitude, point.longitude);
            _selectedPoints.add(latLng);

            final markerId = MarkerId('point_$_markerIdCounter');
            _markerIdCounter++;

            _markers.add(
              Marker(
                markerId: markerId,
                position: latLng,
                infoWindow: InfoWindow(
                  title: "Point ${_selectedPoints.length}",
                  snippet: "Tap to remove",
                  onTap: () {
                    _removePoint(_selectedPoints.indexOf(latLng));
                  },
                ),
              ),
            );
          }

          // Update polylines
          if (_selectedPoints.length > 1) {
            _updatePolylines();
          }
        });

        // Center map on the route if map controller is available
        if (_mapController != null && _selectedPoints.isNotEmpty) {
          _fitMapToRoute();
        }

        _showSnackbar('Route imported successfully!');
      } catch (e) {
        _showSnackbar('Error importing route: ${e.toString()}');
      }
    }
  }

  // Fit map to show all points
  void _fitMapToRoute() {
    if (_mapController == null || _selectedPoints.isEmpty) return;

    // Calculate bounds
    double minLat = _selectedPoints.first.latitude;
    double maxLat = _selectedPoints.first.latitude;
    double minLng = _selectedPoints.first.longitude;
    double maxLng = _selectedPoints.first.longitude;

    for (var point in _selectedPoints) {
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

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _importFromQrCode,
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
                  GoogleMap(
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    compassEnabled: true,
                    mapType: MapType.normal,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_selectedPoints.length > 1) {
                        _updatePolylines();
                      }
                    },
                    onTap: _addPoint,
                    initialCameraPosition:
                        (_hasPermissionReady && _currentLocation != null)
                            ? CameraPosition(
                                target: _currentLocation!,
                                zoom: 14.0,
                              )
                            : const CameraPosition(
                                target: LatLng(20.9834277, 105.8187993),
                                zoom: 2.0,
                              ),
                  ),
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
                        'Tap on map to add points (${_selectedPoints.length} selected)',
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
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Route Name',
                      hintText: 'Enter a name for your route',
                    ),
                  ),
                  TextField(
                    controller: _descriptionController,
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
              value: _isFavorite,
              onChanged: (bool value) {
                setState(() {
                  _isFavorite = value;
                });
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
                      onPressed: _isSaving ? null : _saveRoute,
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Save Route'),
                    ),
                  ),
                  if (_selectedPoints.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _selectedPoints.clear();
                          _markers.clear();
                          _markerIdCounter = 0;
                          _polylines.clear();
                        });
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
}

// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _hasScanned = false;

  // In order to get hot reload working, we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Route QR Code'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Theme.of(context).primaryColor,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Scan a QR code to import a route',
                style: TextStyle(fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_hasScanned) {
        _hasScanned = true;
        // Navigator.of(context).pop(scanData.code);
        _popWithString(scanData.code);
      }
    });
  }

  void _popWithString(String value) {
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
