import 'dart:async';

import 'package:citycab/models/user.dart';
import 'package:citycab/repositories/user_repository.dart';
import 'package:citycab/services/auth.dart';
import 'package:citycab/services/map_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

enum PhoneAuthState { initial, success, loading, codeSent, error }

class AuthState extends ChangeNotifier {
  final authService = AuthService.instance;
  final userRepo = UserRepository.instance;

  PhoneAuthState _phoneAuthState = PhoneAuthState.initial;

  String verificationId = '';

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController licensePlateController = TextEditingController();
  final TextEditingController vehicleColorController = TextEditingController();
  final TextEditingController vehicleTypeController = TextEditingController();
  final TextEditingController vehicleManufacturersController =
      TextEditingController();

  Roles role = Roles.passenger;

  PageController? controller;
  int pageIndex = 0;
  String uid = '';

  int timeOut = 30;
  Timer? _countDownTimer;

  String? uiMessage;

  bool get isRoleDriver => role == Roles.driver;
  PhoneAuthState get phoneAuthState => _phoneAuthState;

  set changeRoleState(int value) {
    role = Roles.values[value];
    notifyListeners();
  }

  set phoneAuthStateChange(PhoneAuthState phoneAuthState) {
    _phoneAuthState = phoneAuthState;
    notifyListeners();
  }

  AuthState(int page, String uid) {
    this.uid = uid;
    controller = PageController(initialPage: page);
    pageIndex = page;
    siginCurrentUser();
  }

  void showMessage(String message) {
    uiMessage = message;
    notifyListeners();
  }

  void clearMessage() {
    uiMessage = null;
    notifyListeners();
  }

  void animateToNextPage(int page) {
    controller?.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeIn,
    );
    pageIndex = page;
    notifyListeners();
  }

  void onPageChanged(int value) {
    pageIndex = value;
    notifyListeners();
  }

  String normalizeSaudiPhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s+'), '').trim();

    if (cleaned.startsWith('+966')) return cleaned;
    if (cleaned.startsWith('966')) return '+$cleaned';
    if (cleaned.startsWith('0')) return '+966${cleaned.substring(1)}';

    return '+966$cleaned';
  }

  void _fillControllersFromUser(User? user) {
    if (user == null) return;

    firstNameController.text = user.firstname;
    lastNameController.text = user.lastname;
    emailController.text = user.email;
    licensePlateController.text = user.licensePlate;
    vehicleColorController.text = user.vehicleColor;
    vehicleTypeController.text = user.vehicleType;
    vehicleManufacturersController.text = user.vehicleManufacturer;
  }

  void _clearDriverFields() {
    licensePlateController.clear();
    vehicleColorController.clear();
    vehicleTypeController.clear();
    vehicleManufacturersController.clear();
  }

  bool _isProfileIncomplete(User? user) {
    return user == null ||
        user.firstname.trim().isEmpty ||
        user.lastname.trim().isEmpty ||
        user.email.trim().isEmpty;
  }

  bool _hasIncompleteDriverFields(User? user) {
    if (role != Roles.driver) return false;

    return user == null ||
        user.vehicleManufacturer.trim().isEmpty ||
        user.vehicleType.trim().isEmpty ||
        user.vehicleColor.trim().isEmpty ||
        user.licensePlate.trim().isEmpty;
  }

  Future<void> signUp() async {
    phoneAuthStateChange = PhoneAuthState.loading;
    final address = await MapService.instance.getCurrentPosition();

    try {
      final saudiPhone =
          firebase_auth.FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

      final user = User(
        uid: uid,
        isActive: role == Roles.driver,
        firstname: firstNameController.text.trim(),
        lastname: lastNameController.text.trim(),
        email: emailController.text.trim(),
        createdAt: DateTime.now(),
        isVerified: true,
        licensePlate:
            role == Roles.driver ? licensePlateController.text.trim() : '',
        phone: saudiPhone,
        vehicleType:
            role == Roles.driver ? vehicleTypeController.text.trim() : '',
        vehicleColor:
            role == Roles.driver ? vehicleColorController.text.trim() : '',
        vehicleManufacturer: role == Roles.driver
            ? vehicleManufacturersController.text.trim()
            : '',
        role: role,
        latlng: address?.latLng,
      );

      await userRepo.setUpAccount(user);
      await userRepo.refreshCurrentUser();

      phoneAuthStateChange = PhoneAuthState.success;
      showMessage('Account setup completed successfully.');
    } on FirebaseException catch (e) {
      phoneAuthStateChange = PhoneAuthState.error;
      showMessage(e.message ?? 'Could not complete sign up.');
    } catch (_) {
      phoneAuthStateChange = PhoneAuthState.error;
      showMessage('Something went wrong while creating your account.');
    }
  }

  Future<void> phoneNumberVerification(String phone) async {
    phoneAuthStateChange = PhoneAuthState.loading;

    final normalizedPhone = normalizeSaudiPhone(phone);

    await authService!.verifyPhoneSendOtp(
      normalizedPhone,
      completed: (credential) async {
        if (credential.smsCode != null && credential.verificationId != null) {
          verificationId = credential.verificationId ?? '';
          notifyListeners();

          await verifyAndLogin(
            credential.verificationId!,
            credential.smsCode!,
            normalizedPhone,
          );
        }
      },
      failed: (error) {
        phoneAuthStateChange = PhoneAuthState.error;
        showMessage(
          error.message ?? 'OTP verification failed. Please try again.',
        );
      },
      codeSent: (String id, int? token) {
        verificationId = id;
        notifyListeners();

        phoneAuthStateChange = PhoneAuthState.codeSent;
        showMessage('OTP code sent successfully.');
        codeSentEvent();
      },
      codeAutoRetrievalTimeout: (id) {
        verificationId = id;
        notifyListeners();

        phoneAuthStateChange = PhoneAuthState.codeSent;
        animateToNextPage(1);
      },
    );
  }

  Future<void> verifyAndLogin(
    String verificationId,
    String smsCode,
    String phone,
  ) async {
    phoneAuthStateChange = PhoneAuthState.loading;

    try {
      final loggedInUid = await authService?.verifyAndLogin(
        verificationId,
        smsCode,
        phone,
      );

      uid = loggedInUid ?? '';

      if (loggedInUid == null || loggedInUid.isEmpty) {
        phoneAuthStateChange = PhoneAuthState.error;
        showMessage('OTP verification failed. Please check the code.');
        return;
      }

      final saudiPhone = normalizeSaudiPhone(phone);

      var user = await userRepo.getUser(loggedInUid);

      if (user == null) {
        user = await userRepo.createUserIfMissing(
          uid: loggedInUid,
          phone: saudiPhone,
        );
        showMessage('Welcome! Please complete your profile.');
      }

      _fillControllersFromUser(user);

      final bool roleMismatch = user != null && user.role != role;
      final bool isProfileIncomplete = _isProfileIncomplete(user);
      final bool needsDriverDetails = _hasIncompleteDriverFields(user);

      if (role == Roles.passenger) {
        _clearDriverFields();
      }

      if (isProfileIncomplete || roleMismatch || needsDriverDetails) {
        phoneAuthStateChange = PhoneAuthState.initial;
        animateToNextPage(2);
        return;
      }

      await userRepo.refreshCurrentUser();
      phoneAuthStateChange = PhoneAuthState.success;
      showMessage('Login successful.');
    } catch (_) {
      phoneAuthStateChange = PhoneAuthState.error;
      showMessage('Invalid OTP or verification failed.');
    }
  }

  Future<void> siginCurrentUser() async {
    await userRepo.signInCurrentUser();
  }

  Future<void> codeSentEvent() async {
    animateToNextPage(1);
    _startCountDown();
  }

  void _startCountDown() {
    _countDownTimer?.cancel();
    timeOut = 30;

    _countDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeOut <= 0) {
        timer.cancel();
      } else {
        timeOut--;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _countDownTimer?.cancel();
    phoneController.dispose();
    otpController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    licensePlateController.dispose();
    vehicleColorController.dispose();
    vehicleTypeController.dispose();
    vehicleManufacturersController.dispose();
    controller?.dispose();
    super.dispose();
  }
}
