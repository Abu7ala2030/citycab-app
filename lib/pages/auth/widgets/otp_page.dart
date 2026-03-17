import 'package:citycab/pages/auth/auth_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/textfields/cab_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OtpPage extends StatefulWidget {
  OtpPage({Key? key}) : super(key: key);

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  String _formattedSaudiNumber(String phone) {
    final cleaned = phone.trim();

    if (cleaned.isEmpty) return '+966';

    if (cleaned.startsWith('+966')) return cleaned;
    if (cleaned.startsWith('966')) return '+$cleaned';

    final normalized = cleaned.startsWith('0') ? cleaned.substring(1) : cleaned;

    return '+966$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AuthState>(context);
    final displayPhone = _formattedSaudiNumber(state.phoneController.text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final message = state.uiMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        state.clearMessage();
      }
    });

    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(CityTheme.elementSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: kToolbarHeight * 0.6),
            Text(
              'Enter Code',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CityTheme.elementSpacing),
            Text(
              'A 6 digit code has been sent to',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              displayPhone,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: CityTheme.elementSpacing),
            CityTextField(
              controller: state.otpController,
              label: 'OTP',
              keyboardType: TextInputType.number,
            ),
            const Spacer(),
            if (state.phoneAuthState == PhoneAuthState.loading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (state.phoneAuthState != PhoneAuthState.loading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (state.otpController.text.trim().length < 6) {
                      state.showMessage('Please enter the 6-digit OTP.');
                      return;
                    }

                    state.verifyAndLogin(
                      state.verificationId,
                      state.otpController.text.trim(),
                      state.phoneController.text.trim(),
                    );
                  },
                  child: const Text('Verify OTP'),
                ),
              ),
            const SizedBox(height: 12),
            if (state.phoneAuthState == PhoneAuthState.codeSent)
              Row(
                children: [
                  Text(
                    'Resend code in ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    '0:${state.timeOut.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
