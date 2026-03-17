import 'dart:async';

import 'package:citycab/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserRepository {
  UserRepository._();

  static UserRepository? _instance;

  static UserRepository get instance {
    _instance ??= UserRepository._();
    return _instance!;
  }

  final CollectionReference<Map<String, dynamic>> _usersCollection =
      FirebaseFirestore.instance.collection('users');

  Roles? get currentUserRole => currentUser?.role;

  final ValueNotifier<User?> userNotifier = ValueNotifier<User?>(null);

  User? get currentUser => userNotifier.value;

  Future<User?> setUpAccount(User user) async {
    try {
      await _usersCollection.doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'firstname': user.firstname,
        'lastname': user.lastname,
        'role': user.role.index,
        'is_verified': user.isVerified,
        'license_plate': user.licensePlate,
        'phone': user.phone,
        'vehicle_type': user.vehicleType,
        'vehicle_color': user.vehicleColor,
        'vehicle_manufacturer': user.vehicleManufacturer,
        'is_active': user.isActive,
        'createdAt': user.createdAt,
        'latlng': {
          'lat': user.latlng?.latitude ?? 0.0,
          'lng': user.latlng?.longitude ?? 0.0,
        },
      }, SetOptions(merge: true));

      return await getUser(user.uid);
    } on FirebaseException catch (e) {
      debugPrint('setUpAccount failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('setUpAccount unexpected error: $e');
      return null;
    }
  }

  Future<User?> getUser(String? uid) async {
    if (uid == null || uid.isEmpty) return null;

    try {
      final userSnapshot = await _usersCollection.doc(uid).get();

      if (!userSnapshot.exists) {
        userNotifier.value = null;
        userNotifier.notifyListeners();
        return null;
      }

      final data = userSnapshot.data();
      if (data == null) {
        userNotifier.value = null;
        userNotifier.notifyListeners();
        return null;
      }

      final user = User.fromMap(data);
      userNotifier.value = user;
      userNotifier.notifyListeners();
      return user;
    } on FirebaseException catch (e) {
      debugPrint('getUser failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('getUser unexpected error: $e');
      return null;
    }
  }

  Future<User?> fetchUserById(String? uid) async {
    if (uid == null || uid.isEmpty) return null;

    try {
      final userSnapshot = await _usersCollection.doc(uid).get();

      if (!userSnapshot.exists) {
        return null;
      }

      final data = userSnapshot.data();
      if (data == null) return null;

      return User.fromMap(data);
    } on FirebaseException catch (e) {
      debugPrint('fetchUserById failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('fetchUserById unexpected error: $e');
      return null;
    }
  }

  Stream<User?> listenToUser(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Stream<User?>.value(null);
    }

    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      final user = User.fromMap(data);

      if (currentUser?.uid == uid) {
        userNotifier.value = user;
        userNotifier.notifyListeners();
      }

      return user;
    });
  }

  Future<void> signInCurrentUser() async {
    if (currentUser != null) return;

    auth.User? authUser = auth.FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      try {
        authUser = await auth.FirebaseAuth.instance.authStateChanges().first;
      } catch (e) {
        debugPrint('authStateChanges failed: $e');
      }
    }

    if (authUser == null) {
      debugPrint('No authenticated Firebase user found');
      userNotifier.value = null;
      userNotifier.notifyListeners();
      return;
    }

    await getUser(authUser.uid);
  }

  Future<User?> createUserIfMissing({
    required String uid,
    required String phone,
  }) async {
    try {
      final userDoc = _usersCollection.doc(uid);
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        await userDoc.set({
          'uid': uid,
          'email': '',
          'firstname': '',
          'lastname': '',
          'phone': phone,
          'role': Roles.passenger.index,
          'createdAt': FieldValue.serverTimestamp(),
          'is_verified': false,
          'license_plate': '',
          'vehicle_type': '',
          'vehicle_color': '',
          'vehicle_manufacturer': '',
          'is_active': false,
          'latlng': {
            'lat': 0.0,
            'lng': 0.0,
          },
        }, SetOptions(merge: true));
      }

      return await getUser(uid);
    } on FirebaseException catch (e) {
      debugPrint('createUserIfMissing failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('createUserIfMissing unexpected error: $e');
      return null;
    }
  }

  Future<User?> updateDriverLocation(String? uid, LatLng position) async {
    if (uid == null || uid.isEmpty) return null;

    try {
      await _usersCollection.doc(uid).update({
        'latlng': {
          'lat': position.latitude,
          'lng': position.longitude,
        },
      });

      if (currentUser?.uid == uid) {
        return await getUser(uid);
      }

      return await fetchUserById(uid);
    } on FirebaseException catch (e) {
      debugPrint('updateDriverLocation failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('updateDriverLocation unexpected error: $e');
      return null;
    }
  }

  Future<User?> updateOnlinePresence(String? uid, bool isActive) async {
    if (uid == null || uid.isEmpty) return null;

    try {
      await _usersCollection.doc(uid).update({
        'is_active': isActive,
      });

      if (currentUser?.uid == uid) {
        return await getUser(uid);
      }

      return await fetchUserById(uid);
    } on FirebaseException catch (e) {
      debugPrint('updateOnlinePresence failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('updateOnlinePresence unexpected error: $e');
      return null;
    }
  }

  Future<User?> updateOnlinePresense(String? uid, bool isActive) async {
    return updateOnlinePresence(uid, isActive);
  }

  Future<User?> refreshCurrentUser() async {
    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return await getUser(uid);
  }

  Future<void> clearCurrentUser() async {
    userNotifier.value = null;
    userNotifier.notifyListeners();
  }
}
