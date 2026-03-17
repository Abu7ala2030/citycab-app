import 'package:citycab/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static AuthService? _instance;

  static AuthService? get instance {
    _instance ??= AuthService._();
    return _instance;
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> verifyPhoneSendOtp(
    String phone, {
    required void Function(PhoneAuthCredential)? completed,
    required void Function(FirebaseAuthException)? failed,
    required void Function(String, int?)? codeSent,
    required void Function(String)? codeAutoRetrievalTimeout,
  }) async {
    print('verifyPhoneSendOtp called with: $phone');

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        print('verificationCompleted fired');
        completed?.call(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        print('verificationFailed fired: ${e.code} | ${e.message}');
        failed?.call(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        print('codeSent fired: $verificationId');
        codeSent?.call(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print('codeAutoRetrievalTimeout fired: $verificationId');
        codeAutoRetrievalTimeout?.call(verificationId);
      },
    );
  }

  Future<String?> verifyAndLogin(
    String verificationId,
    String smsCode,
    String phone,
  ) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final authCredential = await _auth.signInWithCredential(credential);

      if (authCredential.user != null) {
        print('signInWithCredential success: ${authCredential.user!.uid}');
        return authCredential.user!.uid;
      }

      print('signInWithCredential returned null user');
      return null;
    } on FirebaseAuthException catch (e) {
      print('verifyAndLogin FirebaseAuthException: ${e.code} | ${e.message}');
      rethrow;
    } catch (e) {
      print('verifyAndLogin error: $e');
      rethrow;
    }
  }

  Future<String> getCredential(PhoneAuthCredential credential) async {
    final authCredential = await _auth.signInWithCredential(credential);
    return authCredential.user!.uid;
  }

  Future<bool?> logOut() async {
    await _auth.signOut();
    UserRepository.instance.userNotifier.value = null;
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    UserRepository.instance.userNotifier.notifyListeners();
    return true;
  }
}
