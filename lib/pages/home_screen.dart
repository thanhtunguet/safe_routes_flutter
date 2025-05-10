import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saferoute/models/route.dart' as model;
import 'package:saferoute/pages/create_route_screen.dart';
import 'package:saferoute/pages/route_details_screen.dart';
import 'package:saferoute/providers/route_provider.dart';
import 'package:saferoute/providers/toast_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Show confirmation dialog before deleting a route
  Future<void> _confirmDeleteRoute(
      BuildContext context, WidgetRef ref, model.Route route) async {
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
      if (context.mounted) {
        await _deleteRoute(context, ref, route);
      }
    }
  }

  // Delete a route and refresh the list
  Future<void> _deleteRoute(
      BuildContext context, WidgetRef ref, model.Route route) async {
    try {
      await ref.read(routeProvider.notifier).deleteRoute(route.name);
      if (context.mounted) {
        ref
            .read(toastProvider.notifier)
            .showSuccess(context, 'Route "${route.name}" deleted');
      }
    } catch (e) {
      if (context.mounted) {
        ref
            .read(toastProvider.notifier)
            .showError(context, 'Error deleting route: ${e.toString()}');
      }
    }
  }

  void _showQrCodeModal(BuildContext context, model.Route route) async {
    // Convert route to JSON and encode as string
    final routeJson = jsonEncode(route.toJson());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share "${route.name}"'),
        content: Container(
          width: 280,
          height: 300,
          decoration: const BoxDecoration(),
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

  Widget _buildRouteItem(
      BuildContext context, WidgetRef ref, model.Route route) {
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
              onPressed: () => _showQrCodeModal(context, route),
              tooltip: 'Share via QR Code',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDeleteRoute(context, ref, route),
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
              .then((_) => ref.invalidate(routeProvider));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Safe Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(routeProvider),
            tooltip: 'Refresh Routes',
          ),
        ],
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(toastProvider.notifier)
                .showError(context, 'Error loading routes: $error');
          });
          return const Center(child: Text('Failed to load routes'));
        },
        data: (routes) {
          if (routes.isEmpty) {
            return Center(
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
                              builder: (context) => const CreateRouteScreen(),
                            ),
                          )
                          .then((_) => ref.refresh(routeProvider));
                    },
                    child: const Text('Create a new route'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) =>
                _buildRouteItem(context, ref, routes[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => const CreateRouteScreen(),
                ),
              )
              .then((_) => ref.refresh(routeProvider));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
