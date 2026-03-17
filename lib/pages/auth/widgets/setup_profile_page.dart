import 'package:citycab/models/user.dart';
import 'package:citycab/pages/auth/auth_state.dart';
import 'package:citycab/ui/theme.dart';
import 'package:citycab/ui/widget/textfields/cab_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SetupProfilePage extends StatelessWidget {
  SetupProfilePage({Key? key}) : super(key: key);

  final List<String> roleLabels = const <String>[
    'Passenger',
    'Driver',
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AuthState>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final message = state.uiMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        state.clearMessage();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CityTheme.elementSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: CityTheme.elementSpacing),
              Text(
                'Please complete your account details to continue.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: CityTheme.elementSpacing),
              CityTextField(
                controller: state.firstNameController,
                label: 'First Name',
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 12),
              CityTextField(
                controller: state.lastNameController,
                label: 'Last Name',
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 12),
              CityTextField(
                controller: state.emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Text(
                'Select Role',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(roleLabels.length, (index) {
                  final isSelected = state.role.index == index;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == 0 ? 8 : 0,
                        left: index == 1 ? 8 : 0,
                      ),
                      child: OutlinedButton(
                        onPressed: () {
                          state.changeRoleState = index;
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              isSelected ? CityTheme.cityblue : Colors.white,
                          foregroundColor:
                              isSelected ? Colors.white : Colors.black,
                          side: BorderSide(
                            color: isSelected
                                ? CityTheme.cityblue
                                : Colors.grey.shade400,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(roleLabels[index]),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              if (state.role == Roles.driver) ...[
                CityTextField(
                  controller: state.vehicleManufacturersController,
                  label: 'Vehicle Manufacturer',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                CityTextField(
                  controller: state.vehicleTypeController,
                  label: 'Vehicle Type',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                CityTextField(
                  controller: state.vehicleColorController,
                  label: 'Vehicle Color',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                CityTextField(
                  controller: state.licensePlateController,
                  label: 'License Plate',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.phoneAuthState == PhoneAuthState.loading
                      ? null
                      : () {
                          if (state.firstNameController.text.trim().isEmpty ||
                              state.lastNameController.text.trim().isEmpty ||
                              state.emailController.text.trim().isEmpty) {
                            state.showMessage(
                              'Please fill in first name, last name, and email.',
                            );
                            return;
                          }

                          if (state.role == Roles.driver &&
                              (state.vehicleManufacturersController.text
                                      .trim()
                                      .isEmpty ||
                                  state.vehicleTypeController.text
                                      .trim()
                                      .isEmpty ||
                                  state.vehicleColorController.text
                                      .trim()
                                      .isEmpty ||
                                  state.licensePlateController.text
                                      .trim()
                                      .isEmpty)) {
                            state.showMessage(
                              'Please complete all vehicle details.',
                            );
                            return;
                          }

                          state.signUp();
                        },
                  child: state.phoneAuthState == PhoneAuthState.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Complete Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
