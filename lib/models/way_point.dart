import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 2)
class WayPoint {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  WayPoint({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory WayPoint.fromJson(Map<String, dynamic> json) {
    return WayPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }
}
