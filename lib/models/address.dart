import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Address {
  final String id;
  final String? title;
  final String street;
  final String city;
  final String state;
  final String country;
  final String postcode;
  final LatLng latLng;
  final List<PointLatLng> polylines;

  const Address({
    required this.id,
    this.title,
    required this.polylines,
    required this.latLng,
    required this.street,
    required this.city,
    required this.state,
    required this.country,
    required this.postcode,
  });

  factory Address.fromMap(Map<String, dynamic> data) {
    final latlng = data['latlng'] as Map<String, dynamic>?;

    final lat = latlng?['lat'];
    final lng = latlng?['lng'];

    return Address(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString(),
      city: data['city']?.toString() ?? '',
      country: data['country']?.toString() ?? '',
      latLng: LatLng(
        lat is num ? lat.toDouble() : 0.0,
        lng is num ? lng.toDouble() : 0.0,
      ),
      polylines: const [],
      postcode: data['post_code']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      street: data['street']?.toString() ?? '',
    );
  }
}
