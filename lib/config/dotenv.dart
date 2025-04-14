import 'package:flutter_dotenv/flutter_dotenv.dart';

extension SafeRouteEnv on DotEnv {
  double get initialLatitude {
    final value = env['INITIAL_LATITUDE'];
    if (value == null) {
      throw Exception('INITIAL_LATITUDE not found in .env');
    }
    return double.parse(value);
  }

  double get initialLongitude {
    final value = env['INITIAL_LONGITUDE'];
    if (value == null) {
      throw Exception('INITIAL_LONGITUDE not found in .env');
    }
    return double.parse(value);
  }

  double get initialZoomLevel {
    final value = env['INITIAL_ZOOM_LEVEL'];
    if (value == null) {
      throw Exception('INITIAL_ZOOM_LEVEL not found in .env');
    }
    return double.parse(value);
  }
}
