import 'package:hive_flutter/hive_flutter.dart';
import 'package:saferoute/models/route.dart';
import 'package:saferoute/models/way_point.dart';

class PointAdapter extends TypeAdapter<WayPoint> {
  @override
  final int typeId = 2;

  @override
  WayPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final Map<int, dynamic> fields = {};

    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }

    return WayPoint(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WayPoint obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude);
  }
}

class RouteAdapter extends TypeAdapter<Route> {
  @override
  final int typeId = 1;

  @override
  Route read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final Map<int, dynamic> fields = {};

    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }

    return Route(
      name: fields[0] as String,
      isFavorite: fields[1] as bool?,
      points: (fields[2] as List).cast<WayPoint>(),
      description: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Route obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isFavorite)
      ..writeByte(2)
      ..write(obj.points)
      ..writeByte(3)
      ..write(obj.description);
  }
}

class RouteService {
  static const String _boxName = 'routes';
  static Box<Route>? _box;

  static Future<void> init() async {
    // Make sure Hive is initialized first
    await Hive.initFlutter();

    // Register Point adapter first (since Route depends on it)
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PointAdapter());
    }

    // Register Route adapter
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RouteAdapter());
    }

    // Open the box
    _box = await Hive.openBox<Route>(_boxName);
  }

  static Future<void> saveRoute(Route route) async {
    await _ensureBoxOpen();
    await _box!.put(route.name, route);
  }

  static Future<void> deleteRoute(String routeName) async {
    await _ensureBoxOpen();
    await _box!.delete(routeName);
  }

  static Future<List<Route>> getAllRoutes() async {
    await _ensureBoxOpen();
    return _box!.values.toList();
  }

  static Future<Route?> getRoute(String routeName) async {
    await _ensureBoxOpen();
    return _box!.get(routeName);
  }

  static Future<List<Route>> getFavoriteRoutes() async {
    await _ensureBoxOpen();
    return _box!.values.where((route) => route.isFavorite == true).toList();
  }

  static Future<void> _ensureBoxOpen() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }

  static Future<void> closeBox() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
