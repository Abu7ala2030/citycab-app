import 'dart:async';

import 'package:citycab/models/rate.dart';
import 'package:citycab/models/ride.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class RideRepository {
  RideRepository._();

  static RideRepository? _instance;

  static RideRepository get instance {
    _instance ??= RideRepository._();
    return _instance!;
  }

  static const List<double> _driverSearchRadiusStepsMeters = <double>[
    3000,
    7000,
    12000,
    20000,
  ];

  static const Duration _driverSearchRetryDelay = Duration(milliseconds: 800);
  static const Duration _driverRequestTimeout = Duration(seconds: 15);

  final CollectionReference<Map<String, dynamic>> _firestoreRideCollection =
      FirebaseFirestore.instance.collection('rides');

  final CollectionReference<Map<String, dynamic>> _firestoreUsersCollection =
      FirebaseFirestore.instance.collection('users');

  final ValueNotifier<List<Ride>> ridesNotifier = ValueNotifier<List<Ride>>([]);

  final List<StreamSubscription> _subscriptions = [];

  List<Ride> get rides => ridesNotifier.value;

  Future<Ride?> loadRide(String id) async {
    try {
      final doc = await _firestoreRideCollection.doc(id).get();
      if (!doc.exists) return null;

      final ride = Ride.fromMap(doc.data() ?? {});
      _upsertRide(ride);
      return ride;
    } on FirebaseException catch (e) {
      debugPrint('loadRide failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('loadRide unexpected error: $e');
      return null;
    }
  }

  Stream<Ride?> listenToRide(String rideId) {
    return _firestoreRideCollection.doc(rideId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return Ride.fromMap(snapshot.data() ?? {});
    });
  }

  Future<List<Ride>> loadAllUserRides(String ownerUID) async {
    try {
      final subscription = _firestoreRideCollection
          .where('owner_uid', isEqualTo: ownerUID)
          .snapshots()
          .listen(_addToRides);

      _subscriptions.add(subscription);
      return rides;
    } on FirebaseException catch (e) {
      debugPrint('loadAllUserRides failed: ${e.message}');
      return rides;
    } catch (e) {
      debugPrint('loadAllUserRides unexpected error: $e');
      return rides;
    }
  }

  void _addToRides(QuerySnapshot<Map<String, dynamic>> query) {
    final updated = List<Ride>.from(ridesNotifier.value);

    for (final doc in query.docs) {
      final ride = Ride.fromMap(doc.data());
      final index = updated.indexWhere((rideX) => rideX.id == ride.id);

      if (index != -1) {
        updated[index] = ride;
      } else {
        updated.add(ride);
      }
    }

    ridesNotifier.value = updated;
    ridesNotifier.notifyListeners();
  }

  void _upsertRide(Ride ride) {
    final updated = List<Ride>.from(ridesNotifier.value);
    final index = updated.indexWhere((item) => item.id == ride.id);

    if (index != -1) {
      updated[index] = ride;
    } else {
      updated.add(ride);
    }

    ridesNotifier.value = updated;
    ridesNotifier.notifyListeners();
  }

  Future<Ride?> cancelRide(String id) async {
    try {
      await _firestoreRideCollection.doc(id).update({
        'status': RideStatus.cancel.index,
        'candidate_driver_uids': <String>[],
        'request_expires_at': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return await loadRide(id);
    } on FirebaseException catch (e) {
      debugPrint('cancelRide failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('cancelRide unexpected error: $e');
      return null;
    }
  }

  Future<Ride?> boardRide(Ride ride) async {
    try {
      final startAddress = ride.startAddress;
      final endAddress = ride.endAddress;
      final rideOption = ride.rideOption;

      await _firestoreRideCollection.doc(ride.id).set({
        'id': ride.id,
        'createdAt': ride.createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
        'driver_uid': '',
        'owner_uid': ride.ownerUID,
        'status': RideStatus.requesting.index,
        'passengers': ride.passengers,
        'candidate_driver_uids': <String>[],
        'rejected_driver_uids': <String>[],
        'request_expires_at': null,
        'search_wave': -1,
        'rate': {
          'uid': ride.ownerUID,
          'subject': '',
          'body': '',
          'stars': 0,
        },
        'ride_option': {
          'id': rideOption.id,
          'price': rideOption.price,
          'ride_type': rideOption.title,
          'time_of_arrival': rideOption.timeOfArrival,
          'icon': rideOption.icon,
        },
        'start_address': {
          'id': startAddress.id,
          'street': startAddress.street,
          'city': startAddress.city,
          'country': startAddress.country,
          'state': startAddress.state,
          'post_code': startAddress.postcode,
          'latlng': {
            'lat': startAddress.latLng.latitude,
            'lng': startAddress.latLng.longitude,
          },
        },
        'end_address': {
          'id': endAddress.id,
          'street': endAddress.street,
          'city': endAddress.city,
          'country': endAddress.country,
          'state': endAddress.state,
          'post_code': endAddress.postcode,
          'latlng': {
            'lat': endAddress.latLng.latitude,
            'lng': endAddress.latLng.longitude,
          },
        },
      });

      unawaited(_broadcastRideRequest(ride.id, waveIndex: 0));
      return await loadRide(ride.id);
    } on FirebaseException catch (e) {
      debugPrint('boardRide failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('boardRide unexpected error: $e');
      return null;
    }
  }

  Future<void> driverAcceptRide(String rideId, String driverUID) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final ref = _firestoreRideCollection.doc(rideId);
        final snapshot = await transaction.get(ref);

        if (!snapshot.exists) return;

        final ride = Ride.fromMap(snapshot.data() ?? {});

        if (ride.driverUID.isNotEmpty) return;
        if (ride.status != RideStatus.requesting) return;
        if (!ride.candidateDriverUIDs.contains(driverUID)) return;
        if (ride.isRequestExpired) return;

        transaction.update(ref, {
          'driver_uid': driverUID,
          'status': RideStatus.accepted.index,
          'candidate_driver_uids': <String>[],
          'request_expires_at': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      debugPrint('driverAcceptRide failed: ${e.message}');
    } catch (e) {
      debugPrint('driverAcceptRide unexpected error: $e');
    }
  }

  Future<void> driverRejectRide(String rideId, String driverUID) async {
    try {
      final ride = await loadRide(rideId);
      if (ride == null) return;
      if (ride.status != RideStatus.requesting) return;

      final updatedRejected = <String>{
        ...ride.rejectedDriverUIDs,
        driverUID,
      }.toList();

      final updatedCandidates = List<String>.from(ride.candidateDriverUIDs)
        ..remove(driverUID);

      await _firestoreRideCollection.doc(rideId).update({
        'rejected_driver_uids': updatedRejected,
        'candidate_driver_uids': updatedCandidates,
        'request_expires_at': updatedCandidates.isEmpty
            ? null
            : ride.requestExpiresAt != null
                ? Timestamp.fromDate(ride.requestExpiresAt!)
                : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (ride.driverUID.isEmpty) {
        unawaited(
          _broadcastRideRequest(
            rideId,
            waveIndex: ride.searchWave < 0 ? 0 : ride.searchWave,
          ),
        );
      }
    } on FirebaseException catch (e) {
      debugPrint('driverRejectRide failed: ${e.message}');
    } catch (e) {
      debugPrint('driverRejectRide unexpected error: $e');
    }
  }

  Future<void> _broadcastRideRequest(
    String rideId, {
    required int waveIndex,
  }) async {
    try {
      final ride = await loadRide(rideId);
      if (ride == null) return;

      if (ride.driverUID.isNotEmpty) return;
      if (ride.status == RideStatus.cancel ||
          ride.status == RideStatus.completed ||
          ride.status == RideStatus.expired) {
        return;
      }

      final _DispatchCandidateResult? nextCandidate =
          await _findNextDriverCandidate(
        ride: ride,
        waveIndex: waveIndex,
      );

      if (nextCandidate == null) {
        await _markRideExpired(rideId);
        return;
      }

      final expiresAt = DateTime.now().add(_driverRequestTimeout);

      await _firestoreRideCollection.doc(rideId).update({
        'status': RideStatus.requesting.index,
        'candidate_driver_uids': <String>[nextCandidate.driverUID],
        'request_expires_at': Timestamp.fromDate(expiresAt),
        'search_wave': nextCandidate.waveIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      unawaited(
        _handleRequestTimeout(
          rideId: rideId,
          waveIndex: nextCandidate.waveIndex,
          candidateUID: nextCandidate.driverUID,
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('_broadcastRideRequest failed: ${e.message}');
      await _markRideExpired(rideId);
    } catch (e) {
      debugPrint('_broadcastRideRequest unexpected error: $e');
      await _markRideExpired(rideId);
    }
  }

  Future<_DispatchCandidateResult?> _findNextDriverCandidate({
    required Ride ride,
    required int waveIndex,
  }) async {
    int searchIndex = waveIndex < 0 ? 0 : waveIndex;

    while (searchIndex < _driverSearchRadiusStepsMeters.length) {
      final List<_DriverCandidate> candidates = await _loadNearbyDrivers(
        ride: ride,
        radiusMeters: _driverSearchRadiusStepsMeters[searchIndex],
      );

      if (candidates.isNotEmpty) {
        return _DispatchCandidateResult(
          driverUID: candidates.first.uid,
          waveIndex: searchIndex,
        );
      }

      await Future<void>.delayed(_driverSearchRetryDelay);
      searchIndex++;
    }

    return null;
  }

  Future<List<_DriverCandidate>> _loadNearbyDrivers({
    required Ride ride,
    required double radiusMeters,
  }) async {
    final driversSnapshot = await _firestoreUsersCollection
        .where('role', isEqualTo: 1)
        .where('is_active', isEqualTo: true)
        .get();

    if (driversSnapshot.docs.isEmpty) {
      return <_DriverCandidate>[];
    }

    final excludedDriverUIDs = <String>{
      ...ride.rejectedDriverUIDs,
      ...ride.candidateDriverUIDs,
    };

    final List<_DriverCandidate> nearbyDrivers = <_DriverCandidate>[];

    for (final doc in driversSnapshot.docs) {
      final data = doc.data();

      if (doc.id == ride.ownerUID) continue;
      if (excludedDriverUIDs.contains(doc.id)) continue;

      final coords = _extractDriverCoordinates(data);
      if (coords == null) continue;

      final lat = coords['lat']!;
      final lng = coords['lng']!;

      if (lat == 0.0 && lng == 0.0) continue;

      final distance = Geolocator.distanceBetween(
        ride.startAddress.latLng.latitude,
        ride.startAddress.latLng.longitude,
        lat,
        lng,
      );

      if (distance > radiusMeters) continue;

      nearbyDrivers.add(
        _DriverCandidate(
          uid: doc.id,
          distanceMeters: distance,
        ),
      );
    }

    nearbyDrivers.sort((a, b) {
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return nearbyDrivers;
  }

  Future<void> _handleRequestTimeout({
    required String rideId,
    required int waveIndex,
    required String candidateUID,
  }) async {
    await Future<void>.delayed(_driverRequestTimeout);

    try {
      final ride = await loadRide(rideId);
      if (ride == null) return;

      if (ride.driverUID.isNotEmpty) return;
      if (ride.status != RideStatus.requesting) return;
      if (ride.searchWave != waveIndex) return;
      if (!ride.candidateDriverUIDs.contains(candidateUID)) return;

      final rejected = <String>{
        ...ride.rejectedDriverUIDs,
        candidateUID,
      }.toList();

      await _firestoreRideCollection.doc(rideId).update({
        'rejected_driver_uids': rejected,
        'candidate_driver_uids': <String>[],
        'request_expires_at': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _broadcastRideRequest(
        rideId,
        waveIndex: waveIndex,
      );
    } on FirebaseException catch (e) {
      debugPrint('_handleRequestTimeout failed: ${e.message}');
    } catch (e) {
      debugPrint('_handleRequestTimeout unexpected error: $e');
    }
  }

  Future<void> _markRideExpired(String rideId) async {
    await _firestoreRideCollection.doc(rideId).update({
      'driver_uid': '',
      'candidate_driver_uids': <String>[],
      'request_expires_at': null,
      'status': RideStatus.expired.index,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, double>? _extractDriverCoordinates(Map<String, dynamic> data) {
    Map<String, dynamic>? map;

    final rawLatLng = data['latlng'];
    if (rawLatLng is Map<String, dynamic>) {
      map = rawLatLng;
    }

    final rawLatLag = data['latlag'];
    if (map == null && rawLatLag is Map<String, dynamic>) {
      map = rawLatLag;
    }

    if (map == null) return null;

    final dynamic rawLat = map['lat'];
    final dynamic rawLng = map['lng'] ?? map['lag'];

    if (rawLat is! num || rawLng is! num) {
      return null;
    }

    return <String, double>{
      'lat': rawLat.toDouble(),
      'lng': rawLng.toDouble(),
    };
  }

  Future<void> updateRideStatus(String rideId, RideStatus status) async {
    await _firestoreRideCollection.doc(rideId).update({
      'status': status.index,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startRide(String rideId) async {
    await updateRideStatus(rideId, RideStatus.moving);
  }

  Future<void> arriveRide(String rideId) async {
    await updateRideStatus(rideId, RideStatus.arrived);
  }

  Future<void> completeRide(String rideId) async {
    await updateRideStatus(rideId, RideStatus.completed);
  }

  Future<void> submitRideRating(String rideId, Rate rate) async {
    await _firestoreRideCollection.doc(rideId).update({
      'rate': {
        'uid': rate.uid,
        'subject': rate.subject,
        'body': rate.body,
        'stars': rate.stars,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

class _DriverCandidate {
  final String uid;
  final double distanceMeters;

  const _DriverCandidate({
    required this.uid,
    required this.distanceMeters,
  });
}

class _DispatchCandidateResult {
  final String driverUID;
  final int waveIndex;

  const _DispatchCandidateResult({
    required this.driverUID,
    required this.waveIndex,
  });
}
