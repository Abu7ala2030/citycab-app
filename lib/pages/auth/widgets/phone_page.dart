import 'package:citycab/models/user.dart';
import 'package:citycab/pages/auth/auth_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/textfields/cab_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PhonePage extends StatefulWidget {
  const PhonePage({Key? key}) : super(key: key);

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AuthState>(context);

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
              'Enter Phone Number',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CityTheme.elementSpacing),
            Text(
              'Choose how you want to continue, then we will send you a one-time verification code.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: CityTheme.elementSpacing),
            Text(
              'Continue as',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      state.changeRoleState = Roles.passenger.index;
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: state.role == Roles.passenger
                          ? CityTheme.cityblue
                          : Colors.white,
                      foregroundColor: state.role == Roles.passenger
                          ? Colors.white
                          : Colors.black,
                      side: BorderSide(
                        color: state.role == Roles.passenger
                            ? CityTheme.cityblue
                            : Colors.grey.shade400,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Passenger'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      state.changeRoleState = Roles.driver.index;
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: state.role == Roles.driver
                          ? CityTheme.cityblue
                          : Colors.white,
                      foregroundColor: state.role == Roles.driver
                          ? Colors.white
                          : Colors.black,
                      side: BorderSide(
                        color: state.role == Roles.driver
                            ? CityTheme.cityblue
                            : Colors.grey.shade400,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Driver'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CityTheme.elementSpacing),
            CityTextField(
              controller: state.phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
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
                    final phone = state.phoneController.text.trim();

                    if (phone.isEmpty) {
                      state.showMessage('Please enter your phone number.');
                      return;
                    }

                    state.phoneNumberVerification(phone);
                  },
                  child: Text(
                    state.role == Roles.driver
                        ? 'Continue as Driver'
                        : 'Continue as Passenger',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
