import 'package:citycab/pages/auth/auth_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthButton extends StatelessWidget {
  const AuthButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthState>();
    final bool isLoading = state.phoneAuthState == PhoneAuthState.loading;

    return Positioned(
      bottom: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton(
          backgroundColor: isLoading ? Colors.grey[300] : CityTheme.cityblue,
          child: Icon(
            state.pageIndex == 2
                ? Icons.check_rounded
                : Icons.arrow_forward_ios,
          ),
          onPressed: isLoading
              ? null
              : () async {
                  if (state.pageIndex == 0 &&
                      state.phoneController.text.isNotEmpty) {
                    final phone = state.phoneController.text.trim();
                    final normalizedPhone =
                        phone.startsWith('0') ? phone.substring(1) : phone;

                    await state.phoneNumberVerification("+966$normalizedPhone");
                  } else if (state.pageIndex == 1 &&
                      state.otpController.text.isNotEmpty) {
                    await state.verifyAndLogin(
                      state.verificationId,
                      state.otpController.text.trim(),
                      state.phoneController.text.trim(),
                    );
                  } else if (state.pageIndex == 2) {
                    if (state.firstNameController.text.isEmpty ||
                        state.lastNameController.text.isEmpty ||
                        state.emailController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields'),
                        ),
                      );
                      return;
                    }

                    await state.signUp();
                  }
                },
        ),
      ),
    );
  }
}
