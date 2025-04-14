import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saferoute/models/route.dart' as model;
import 'package:saferoute/pages/create_route_screen.dart';
import 'package:saferoute/pages/route_details_screen.dart';
import 'package:saferoute/services/route_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<model.Route> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final routes = await RouteService.getAllRoutes();
      setState(() {
        _routes = routes;
      });
    } catch (e) {
      _showSnackBar('Error loading routes: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Show confirmation dialog before deleting a route
  Future<void> _confirmDeleteRoute(model.Route route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text(
            'Are you sure you want to delete "${route.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteRoute(route);
    }
  }

  // Delete a route and refresh the list
  Future<void> _deleteRoute(model.Route route) async {
    try {
      await RouteService.deleteRoute(route.name);
      _showSnackBar('Route "${route.name}" deleted');
      await _loadRoutes();
    } catch (e) {
      _showSnackBar('Error deleting route: ${e.toString()}');
    }
  }

  void _showQrCodeModal(model.Route route) async {
    // Convert route to JSON and encode as string
    final routeJson = jsonEncode(route.toJson());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share "${route.name}"'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              QrImageView(
                data: routeJson,
                version: QrVersions.auto,
                size: 240.0,
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan this QR code to share the route',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteItem(model.Route route) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          route.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: route.description != null && route.description!.isNotEmpty
            ? Text(route.description!)
            : const Text('No description'),
        leading: CircleAvatar(
          child: Text(route.name.substring(0, 1).toUpperCase()),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (route.isFavorite == true)
              const Icon(
                Icons.favorite,
                color: Colors.red,
              ),
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () => _showQrCodeModal(route),
              tooltip: 'Share via QR Code',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDeleteRoute(route),
              tooltip: 'Delete Route',
              color: Colors.red.shade300,
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => RouteDetailsScreen(route: route),
                ),
              )
              .then((_) => _loadRoutes());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Safe Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoutes,
            tooltip: 'Refresh Routes',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No routes yet',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateRouteScreen(),
                                ),
                              )
                              .then((_) => _loadRoutes());
                        },
                        child: const Text('Create a new route'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _routes.length,
                  itemBuilder: (context, index) =>
                      _buildRouteItem(_routes[index]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => const CreateRouteScreen(),
                ),
              )
              .then((_) => _loadRoutes());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
