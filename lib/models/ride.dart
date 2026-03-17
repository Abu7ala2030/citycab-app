import 'package:citycab/models/address.dart';
import 'package:citycab/models/rate.dart';
import 'package:citycab/models/ride_option.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RideStatus {
  initial,
  requesting,
  accepted,
  moving,
  arrived,
  completed,
  cancel,
  expired,
}

@immutable
class Ride {
  final String id;
  final Address startAddress;
  final Address endAddress;
  final String driverUID;
  final String ownerUID;
  final List<String> passengers;
  final List<String> candidateDriverUIDs;
  final List<String> rejectedDriverUIDs;
  final Rate rate;
  final RideOption rideOption;
  final RideStatus status;
  final DateTime createdAt;
  final DateTime? requestExpiresAt;
  final int searchWave;

  const Ride({
    required this.id,
    required this.startAddress,
    required this.endAddress,
    required this.driverUID,
    required this.ownerUID,
    required this.passengers,
    required this.candidateDriverUIDs,
    required this.rejectedDriverUIDs,
    required this.rate,
    required this.rideOption,
    required this.status,
    required this.createdAt,
    required this.requestExpiresAt,
    required this.searchWave,
  });

  bool get isRequestExpired =>
      requestExpiresAt != null && DateTime.now().isAfter(requestExpiresAt!);

  Ride copyWith({
    String? id,
    Address? startAddress,
    Address? endAddress,
    String? driverUID,
    String? ownerUID,
    List<String>? passengers,
    List<String>? candidateDriverUIDs,
    List<String>? rejectedDriverUIDs,
    Rate? rate,
    RideOption? rideOption,
    RideStatus? status,
    DateTime? createdAt,
    DateTime? requestExpiresAt,
    int? searchWave,
  }) {
    return Ride(
      id: id ?? this.id,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      driverUID: driverUID ?? this.driverUID,
      ownerUID: ownerUID ?? this.ownerUID,
      passengers: passengers ?? this.passengers,
      candidateDriverUIDs: candidateDriverUIDs ?? this.candidateDriverUIDs,
      rejectedDriverUIDs: rejectedDriverUIDs ?? this.rejectedDriverUIDs,
      rate: rate ?? this.rate,
      rideOption: rideOption ?? this.rideOption,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      requestExpiresAt: requestExpiresAt ?? this.requestExpiresAt,
      searchWave: searchWave ?? this.searchWave,
    );
  }

  factory Ride.fromMap(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    final requestExpiresAtRaw = data['request_expires_at'];
    final rawStatus = data['status'];

    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    DateTime? requestExpiresAt;
    if (requestExpiresAtRaw is Timestamp) {
      requestExpiresAt = requestExpiresAtRaw.toDate();
    } else if (requestExpiresAtRaw is DateTime) {
      requestExpiresAt = requestExpiresAtRaw;
    }

    return Ride(
      createdAt: createdAt,
      requestExpiresAt: requestExpiresAt,
      driverUID: data['driver_uid']?.toString() ?? '',
      endAddress: Address.fromMap(
        (data['end_address'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      id: data['id']?.toString() ?? '',
      ownerUID: data['owner_uid']?.toString() ?? '',
      passengers: List<String>.from(data['passengers'] ?? const <String>[]),
      candidateDriverUIDs: List<String>.from(
        data['candidate_driver_uids'] ?? const <String>[],
      ),
      rejectedDriverUIDs: List<String>.from(
        data['rejected_driver_uids'] ?? const <String>[],
      ),
      rate: Rate.fromMap(
        (data['rate'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      rideOption: RideOption.fromMap(
        (data['ride_option'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      startAddress: Address.fromMap(
        (data['start_address'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      status: RideStatus.values[(rawStatus is num ? rawStatus.toInt() : 0)
          .clamp(0, RideStatus.values.length - 1)],
      searchWave: (data['search_wave'] is num)
          ? (data['search_wave'] as num).toInt()
          : -1,
    );
  }
}
