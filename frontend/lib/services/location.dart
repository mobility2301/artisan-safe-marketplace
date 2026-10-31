// ===== SAVE AS:  C:\dev\artisan_app\lib\services\location.dart   (NEW file) =====
import 'dart:async';
 
import 'package:geolocator/geolocator.dart';
 
import 'api.dart';
 
/// Gets the current GPS position (the browser asks for permission in Chrome).
/// Throws an ApiException whose message the user can act on.
Future<Position> getCurrentPosition() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw ApiException('Location permission was denied. Allow location for this page and try again.');
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  } on ApiException {
    rethrow;
  } on TimeoutException {
    throw ApiException('Could not get your location in time. Please try again.');
  } catch (_) {
    throw ApiException('Could not get your location. Check that location is switched on.');
  }
}