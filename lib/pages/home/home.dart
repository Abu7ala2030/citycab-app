import 'package:citycab/models/user.dart';
import 'package:citycab/pages/auth/auth_page.dart';
import 'package:citycab/pages/map/map_view.dart';
import 'package:citycab/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:citycab/pages/map/map_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        color: Colors.grey[200],
        child: ValueListenableBuilder<User?>(
          valueListenable: UserRepository.instance.userNotifier,
          builder: (context, user, child) {
            if (user == null) {
              return const AuthPageWidget(page: 0);
            }

            if (!user.isVerified) {
              return AuthPageWidget(page: 2, uid: user.uid);
            }

            return const MapView();
          },
        ),
      ),
    );
  }
}
