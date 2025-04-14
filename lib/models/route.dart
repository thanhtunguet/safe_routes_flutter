import 'package:hive_flutter/hive_flutter.dart';
import 'package:saferoute/models/way_point.dart';

@HiveType(typeId: 1)
class Route {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final bool? isFavorite;

  @HiveField(2)
  final List<WayPoint> points;

  @HiveField(3)
  final String? description;

  Route({
    required this.name,
    this.isFavorite,
    required this.points,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isFavorite': isFavorite,
      'points': points.map((point) => point.toJson()).toList(),
      'description': description,
    };
  }

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      name: json['name'] as String,
      isFavorite: json['isFavorite'] as bool?,
      points: (json['points'] as List<dynamic>)
          .map((point) => WayPoint.fromJson(point as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
    );
  }
}
