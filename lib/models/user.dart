import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum Roles { passenger, driver, admin }

class User {
  final String uid;
  final String firstname;
  final String lastname;
  final String email;
  final DateTime createdAt;
  final bool isVerified;
  final String licensePlate;
  final String phone;
  final String vehicleType;
  final String vehicleColor;
  final String vehicleManufacturer;
  final Roles role;
  final bool isActive;
  final LatLng? latlng;

  bool get isPassengerRole => role == Roles.passenger;
  bool get isDriverRole => role == Roles.driver;
  bool get isAdminRole => role == Roles.admin;

  String get getFullName => "$firstname $lastname".trim();

  const User({
    required this.isActive,
    required this.uid,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.createdAt,
    required this.isVerified,
    required this.licensePlate,
    required this.phone,
    required this.vehicleType,
    required this.vehicleColor,
    required this.vehicleManufacturer,
    required this.role,
    this.latlng,
  });

  factory User.fromMap(Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    DateTime createdAt;

    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else {
      createdAt = DateTime.now();
    }

    final rawLatLng = data['latlng'];
    LatLng? parsedLatLng;

    if (rawLatLng is Map<String, dynamic>) {
      final rawLat = rawLatLng['lat'];
      final rawLng = rawLatLng['lng'];

      if (rawLat is num && rawLng is num) {
        parsedLatLng = LatLng(rawLat.toDouble(), rawLng.toDouble());
      }
    }

    return User(
      uid: data['uid']?.toString() ?? '',
      isActive: data['is_active'] == true,
      firstname: data['firstname']?.toString() ?? '',
      lastname: data['lastname']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      createdAt: createdAt,
      isVerified: data['is_verified'] == true,
      licensePlate: data['license_plate']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      vehicleType: data['vehicle_type']?.toString() ?? '',
      vehicleColor: data['vehicle_color']?.toString() ?? '',
      vehicleManufacturer: data['vehicle_manufacturer']?.toString() ?? '',
      role:
          Roles.values[(data['role'] is num ? data['role'] as num : 0).toInt()],
      latlng: parsedLatLng,
    );
  }
}
