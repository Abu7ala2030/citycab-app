import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:citycab/constant/google_map_key.dart';
import 'package:citycab/models/address.dart';
import 'package:citycab/models/citycab_info_window.dart';
import 'package:citycab/models/user.dart';
import 'package:citycab/repositories/user_repository.dart';
import 'package:citycab/ui/info_window/custom_info_window.dart';
import 'package:citycab/ui/info_window/custom_widow.dart';
import 'package:citycab/utils/images_assets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'code_generator.dart';

class Delay {
  final int milliseconds;
  Timer? _timer;

  Delay({this.milliseconds = 400});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() {
    _timer?.cancel();
  }
}

class RouteData {
  final List<PointLatLng> polylines;
  final Duration duration;
  final double distanceMeters;

  const RouteData({
    required this.polylines,
    required this.duration,
    required this.distanceMeters,
  });
}

class MapService {
  MapService._();

  static final MapService _instance = MapService._();

  static MapService get instance => _instance;

  static const String currentUserMarkerId = 'current_user_marker';
  static const String destinationMarkerId = 'destination_marker';
  static const String driverMarkerId = 'assigned_driver_marker';

  final String baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  StreamSubscription<Position>? positionStream;
  Duration duration = Duration.zero;

  final Delay _delay = Delay(milliseconds: 500);

  final ValueNotifier<Address?> currentPosition = ValueNotifier<Address?>(null);
  final ValueNotifier<List<Marker>> markers =
      ValueNotifier<List<Marker>>(<Marker>[]);
  final List<Address> searchedAddress = <Address>[];

  final Map<String, BitmapDescriptor> _iconCache = <String, BitmapDescriptor>{};

  Timer? _driverAnimationTimer;
  LatLng? _lastDriverLatLng;
  double _lastDriverRotation = 0;

  CustomInfoWindowController controller = CustomInfoWindowController();

  String get userMapIcon {
    final Roles? userRole = UserRepository.instance.currentUserRole;
    return userRole == Roles.driver ? ImagesAsset.car : ImagesAsset.circlePin;
  }

  void dispose() {
    positionStream?.cancel();
    positionStream = null;
    _driverAnimationTimer?.cancel();
    _driverAnimationTimer = null;
    _delay.cancel();
    controller.hideInfoWindow?.call();
  }

  Future<bool> requestAndCheckPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location service is disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied.');
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Address?> getCurrentPosition() async {
    try {
      final hasPermission = await requestAndCheckPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final address = await getAddressFromCoordinate(
        LatLng(position.latitude, position.longitude),
        id: currentUserMarkerId,
      );

      final icon = await getMapIcon(userMapIcon);
      await addMarker(
        address,
        icon,
        time: DateTime.now(),
        type: InfoWindowType.position,
        position: position,
        markerIdOverride: currentUserMarkerId,
      );

      currentPosition.value = address;
      currentPosition.notifyListeners();
      return address;
    } catch (e) {
      debugPrint('getCurrentPosition error: $e');
      return null;
    }
  }

  Stream<void> listenToPositionChanges({
    required Function(Address?) eventFiring,
  }) async* {
    final hasPermission = await requestAndCheckPermission();
    if (!hasPermission) return;

    await positionStream?.cancel();

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((position) async {
      try {
        final updatedAddress = await getAddressFromCoordinate(
          LatLng(position.latitude, position.longitude),
          id: currentUserMarkerId,
        );

        currentPosition.value = updatedAddress;

        final icon = await getMapIcon(userMapIcon);
        await addMarker(
          updatedAddress,
          icon,
          time: DateTime.now(),
          type: InfoWindowType.position,
          position: position,
          markerIdOverride: currentUserMarkerId,
        );

        currentPosition.notifyListeners();
        eventFiring(updatedAddress);
      } catch (e) {
        debugPrint('listenToPositionChanges error: $e');
      }
    });
  }

  Future<Address> getAddressFromCoordinate(
    LatLng latLng, {
    List<PointLatLng>? polylines,
    String? id,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      final placemark = placemarks.isNotEmpty ? placemarks.first : null;

      return Address(
        id: id ?? UserRepository.instance.currentUser?.uid ?? '',
        street: placemark?.street ?? '',
        city: placemark?.locality ?? '',
        state: placemark?.administrativeArea ?? '',
        country: placemark?.country ?? '',
        latLng: latLng,
        polylines: polylines ?? const [],
        postcode: placemark?.postalCode ?? '',
      );
    } catch (e) {
      debugPrint('getAddressFromCoordinate error: $e');

      return Address(
        id: id ?? UserRepository.instance.currentUser?.uid ?? '',
        street: '',
        city: '',
        state: '',
        country: '',
        latLng: latLng,
        polylines: polylines ?? const [],
        postcode: '',
      );
    }
  }

  @Deprecated('Use getAddressFromCoordinate instead')
  Future<Address> getAddressFromCoodinate(
    LatLng latLng, {
    List<PointLatLng>? polylines,
    String? id,
  }) {
    return getAddressFromCoordinate(
      latLng,
      polylines: polylines,
      id: id,
    );
  }

  Future<List<Address>> getAddressFromQuery(String query) async {
    searchedAddress.clear();

    final normalizedQuery = query.trim();

    if (normalizedQuery.length < 3) {
      return searchedAddress;
    }

    try {
      final locations = await locationFromAddress(normalizedQuery);

      if (locations.isEmpty) {
        return searchedAddress;
      }

      for (final location in locations) {
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isEmpty) continue;

          final placemark = placemarks.first;

          final address = Address(
            id: CodeGenerator.instance!.generateCode('m'),
            street: (placemark.street ?? '').isNotEmpty
                ? placemark.street!
                : normalizedQuery,
            city: placemark.locality ?? '',
            state: placemark.administrativeArea ?? '',
            country: placemark.country ?? '',
            latLng: LatLng(location.latitude, location.longitude),
            polylines: const [],
            postcode: placemark.postalCode ?? '',
          );

          final exists = searchedAddress.any(
            (item) =>
                item.street == address.street &&
                item.city == address.city &&
                item.state == address.state &&
                item.country == address.country,
          );

          if (!exists) {
            searchedAddress.add(address);
          }
        } catch (_) {}
      }
    } catch (_) {
      // silently ignore incomplete search queries
    }

    return searchedAddress;
  }

  Future<Address?> getPosition(LatLng latLng) async {
    try {
      final address = await getAddressFromCoordinate(
        latLng,
        id: currentUserMarkerId,
      );

      _removeMarkerById(currentUserMarkerId);
      _removeMarkerById(destinationMarkerId);
      controller.hideInfoWindow?.call();

      final icon = await getMapIcon(userMapIcon);
      await addMarker(
        address,
        icon,
        time: DateTime.now(),
        type: InfoWindowType.position,
        markerIdOverride: currentUserMarkerId,
      );

      currentPosition.value = address;
      currentPosition.notifyListeners();

      return address;
    } catch (e) {
      debugPrint('getPosition error: $e');
      return null;
    }
  }

  Future<RouteData> getRouteData(
    LatLng startLatLng,
    LatLng endLatLng,
  ) async {
    final uri = Uri.parse(
      '$baseUrl?origin=${startLatLng.latitude},${startLatLng.longitude}'
      '&destination=${endLatLng.latitude},${endLatLng.longitude}'
      '&key=${GoogleMapKey.key}',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Directions API request failed: ${response.statusCode}');
    }

    final Map<String, dynamic> values =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (values['status'] != 'OK') {
      debugPrint('Directions API status: ${values['status']}');
      throw Exception('Directions API returned error');
    }

    final routes = values['routes'] as List<dynamic>? ?? <dynamic>[];
    if (routes.isEmpty) {
      throw Exception('No routes returned from Directions API');
    }

    final route = routes.first as Map<String, dynamic>;
    final overviewPolyline =
        route['overview_polyline'] as Map<String, dynamic>? ??
            <String, dynamic>{};

    final encodedPoints = overviewPolyline['points']?.toString() ?? '';
    if (encodedPoints.isEmpty) {
      throw Exception('No polyline points returned from Directions API');
    }

    final legs = route['legs'] as List<dynamic>? ?? <dynamic>[];
    Duration routeDuration = Duration.zero;
    double routeDistanceMeters = 0;

    if (legs.isNotEmpty) {
      final firstLeg = legs.first as Map<String, dynamic>;

      final durationMap =
          firstLeg['duration'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final distanceMap =
          firstLeg['distance'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final seconds = durationMap['value'];
      final meters = distanceMap['value'];

      routeDuration =
          seconds is num ? Duration(seconds: seconds.toInt()) : Duration.zero;
      routeDistanceMeters = meters is num ? meters.toDouble() : 0;
    }

    final polylines = PolylinePoints.decodePolyline(encodedPoints);

    return RouteData(
      polylines: polylines,
      duration: routeDuration,
      distanceMeters: routeDistanceMeters,
    );
  }

  Future<Address> getRouteCoordinates(
    LatLng? startLatLng,
    LatLng? endLatLng,
  ) async {
    if (startLatLng == null || endLatLng == null) {
      throw Exception('Start or end location is null');
    }

    _removeMarkerById(currentUserMarkerId);
    _removeMarkerById(destinationMarkerId);

    final routeData = await getRouteData(startLatLng, endLatLng);
    duration = routeData.duration;

    final endAddress = await _getEndAddressAndAddMarkers(
      startLatLng,
      endLatLng,
      routeData.polylines,
    );

    return endAddress;
  }

  Future<Address> _getEndAddressAndAddMarkers(
    LatLng startLatLng,
    LatLng endLatLng,
    List<PointLatLng> polylines,
  ) async {
    final endAddress = await getAddressFromCoordinate(
      endLatLng,
      polylines: polylines,
      id: destinationMarkerId,
    );

    final destinationIcon = await getMapIcon(ImagesAsset.pin);
    await addMarker(
      endAddress,
      destinationIcon,
      time: DateTime.now(),
      type: InfoWindowType.destination,
      markerIdOverride: destinationMarkerId,
    );

    final startAddress = await getAddressFromCoordinate(
      startLatLng,
      polylines: polylines,
      id: currentUserMarkerId,
    );

    final startIcon = await getMapIcon(userMapIcon);
    await addMarker(
      startAddress,
      startIcon,
      time: DateTime.now(),
      type: InfoWindowType.position,
      markerIdOverride: currentUserMarkerId,
    );

    currentPosition.value = startAddress;
    currentPosition.notifyListeners();

    return endAddress;
  }

  Future<void> addOrUpdateDriverMarker(User driver) async {
    final LatLng? targetLatLng = driver.latlng;
    if (targetLatLng == null) return;

    final currentMarker = _findMarkerById(driverMarkerId);
    final currentLatLng =
        currentMarker != null ? currentMarker.position : _lastDriverLatLng;
    final icon = await getMapIcon(ImagesAsset.car);

    if (currentLatLng == null) {
      _lastDriverLatLng = targetLatLng;
      _lastDriverRotation = 0;

      final driverAddress = _buildDriverAddress(driver, targetLatLng);

      await addMarker(
        driverAddress,
        icon,
        time: DateTime.now(),
        type: InfoWindowType.position,
        markerIdOverride: driverMarkerId,
        infoLabelOverride: _driverInfoLabel(driver),
        zIndex: 3,
        anchor: const Offset(0.5, 0.5),
        rotationOverride: _lastDriverRotation,
      );
      return;
    }

    final distance = Geolocator.distanceBetween(
      currentLatLng.latitude,
      currentLatLng.longitude,
      targetLatLng.latitude,
      targetLatLng.longitude,
    );

    if (distance < 1.5) {
      _lastDriverLatLng = targetLatLng;

      final driverAddress = _buildDriverAddress(driver, targetLatLng);

      await addMarker(
        driverAddress,
        icon,
        time: DateTime.now(),
        type: InfoWindowType.position,
        markerIdOverride: driverMarkerId,
        infoLabelOverride: _driverInfoLabel(driver),
        zIndex: 3,
        anchor: const Offset(0.5, 0.5),
        rotationOverride: _lastDriverRotation,
      );
      return;
    }

    await _animateDriverMarker(
      driver: driver,
      from: currentLatLng,
      to: targetLatLng,
      icon: icon,
    );
  }

  Future<void> _animateDriverMarker({
    required User driver,
    required LatLng from,
    required LatLng to,
    required BitmapDescriptor icon,
  }) async {
    _driverAnimationTimer?.cancel();
    _driverAnimationTimer = null;

    const int totalSteps = 20;
    const int stepMilliseconds = 120;

    final double bearing = _calculateBearing(from, to);
    _lastDriverRotation = bearing;

    int step = 0;
    final completer = Completer<void>();

    _driverAnimationTimer = Timer.periodic(
      const Duration(milliseconds: stepMilliseconds),
      (timer) async {
        step++;

        final double t = step / totalSteps;
        final double lat = from.latitude + ((to.latitude - from.latitude) * t);
        final double lng =
            from.longitude + ((to.longitude - from.longitude) * t);

        final LatLng interpolated = LatLng(lat, lng);
        _lastDriverLatLng = interpolated;

        final driverAddress = _buildDriverAddress(driver, interpolated);

        await addMarker(
          driverAddress,
          icon,
          time: DateTime.now(),
          type: InfoWindowType.position,
          markerIdOverride: driverMarkerId,
          infoLabelOverride: _driverInfoLabel(driver),
          zIndex: 3,
          anchor: const Offset(0.5, 0.5),
          rotationOverride: bearing,
        );

        if (step >= totalSteps) {
          timer.cancel();
          _lastDriverLatLng = to;
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      },
    );

    return completer.future;
  }

  Address _buildDriverAddress(User driver, LatLng latLng) {
    return Address(
      id: driverMarkerId,
      title: driver.getFullName,
      street: driver.vehicleManufacturer,
      city: driver.vehicleType,
      state: '',
      country: '',
      postcode: driver.licensePlate,
      latLng: latLng,
      polylines: const [],
    );
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final double lat1 = _degreesToRadians(from.latitude);
    final double lon1 = _degreesToRadians(from.longitude);
    final double lat2 = _degreesToRadians(to.latitude);
    final double lon2 = _degreesToRadians(to.longitude);

    final double dLon = lon2 - lon1;

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = _radiansToDegrees(math.atan2(y, x));
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  double _radiansToDegrees(double radians) {
    return radians * (180.0 / math.pi);
  }

  Marker? _findMarkerById(String markerId) {
    try {
      return markers.value.firstWhere(
        (item) => item.markerId.value == markerId,
      );
    } catch (_) {
      return null;
    }
  }

  void removeDriverMarker() {
    _driverAnimationTimer?.cancel();
    _driverAnimationTimer = null;
    _lastDriverLatLng = null;
    _lastDriverRotation = 0;
    _removeMarkerById(driverMarkerId);
  }

  void clearRouteMarkers() {
    _removeMarkerById(currentUserMarkerId);
    _removeMarkerById(destinationMarkerId);
  }

  Future<List<Marker>> addMarker(
    Address? address,
    BitmapDescriptor icon, {
    required DateTime time,
    required InfoWindowType type,
    Position? position,
    String? markerIdOverride,
    String? infoLabelOverride,
    double zIndex = 2,
    Offset anchor = const Offset(0.5, 0.5),
    double? rotationOverride,
  }) async {
    if (address == null) return markers.value;

    final String resolvedMarkerId = markerIdOverride ?? address.id;

    final marker = Marker(
      markerId: MarkerId(resolvedMarkerId),
      position: address.latLng,
      icon: icon,
      rotation: rotationOverride ?? position?.heading ?? 0,
      anchor: anchor,
      zIndex: zIndex,
      onTap: () {
        controller.addInfoWindow?.call(
          CustomWindow(
            info: CityCabInfoWindow(
              name: infoLabelOverride ?? _formatAddressLabel(address),
              position: address.latLng,
              type: type,
              time: duration,
            ),
          ),
          address.latLng,
        );
      },
    );

    final updatedMarkers = List<Marker>.from(markers.value);
    final index = updatedMarkers.indexWhere(
      (item) => item.markerId.value == resolvedMarkerId,
    );

    if (index != -1) {
      updatedMarkers[index] = marker;
    } else {
      updatedMarkers.add(marker);
    }

    markers.value = updatedMarkers;
    markers.notifyListeners();

    return markers.value;
  }

  void _removeMarkerById(String markerId) {
    final updatedMarkers = List<Marker>.from(markers.value)
      ..removeWhere((item) => item.markerId.value == markerId);

    markers.value = updatedMarkers;
    markers.notifyListeners();
  }

  String _formatAddressLabel(Address address) {
    final parts = <String>[
      address.street.trim(),
      address.city.trim(),
    ].where((part) => part.isNotEmpty).toList();

    return parts.isEmpty ? 'Selected location' : parts.join(', ');
  }

  String _driverInfoLabel(User driver) {
    final parts = <String>[
      driver.getFullName.trim(),
      driver.vehicleManufacturer.trim(),
      driver.vehicleType.trim(),
      driver.licensePlate.trim(),
    ].where((part) => part.isNotEmpty).toList();

    return parts.isEmpty ? 'Driver location' : parts.join(' • ');
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to convert asset to bytes: $path');
    }

    return byteData.buffer.asUint8List();
  }

  Future<BitmapDescriptor> getMapIcon(String iconPath) async {
    final cached = _iconCache[iconPath];
    if (cached != null) {
      return cached;
    }

    final bytes = await getBytesFromAsset(iconPath, 65);
    final icon = BitmapDescriptor.fromBytes(bytes);
    _iconCache[iconPath] = icon;
    return icon;
  }
}
