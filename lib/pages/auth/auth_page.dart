import 'package:citycab/pages/auth/auth_state.dart';
import 'package:citycab/pages/auth/widgets/otp_page.dart';
import 'package:citycab/pages/auth/widgets/phone_page.dart';
import 'package:citycab/pages/auth/widgets/setup_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthPage extends StatelessWidget {
  final int page;
  final String uid;

  const AuthPage({
    Key? key,
    required this.page,
    this.uid = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AuthPageWidget(
      page: page,
      uid: uid,
    );
  }
}

class AuthPageWidget extends StatelessWidget {
  final int page;
  final String uid;

  const AuthPageWidget({
    Key? key,
    required this.page,
    this.uid = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthState>(
      create: (_) => AuthState(page, uid),
      child: Consumer<AuthState>(
        builder: (context, state, child) {
          return Scaffold(
            body: PageView(
              controller: state.controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: state.onPageChanged,
              children: [
                const PhonePage(),
                OtpPage(),
                SetupProfilePage(),
              ],
            ),
          );
        },
      ),
    );
  }
}
