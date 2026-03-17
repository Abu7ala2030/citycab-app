import 'package:citycab/pages/auth/auth_page.dart';
import 'package:citycab/pages/map/map_view.dart';
import 'package:citycab/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({Key? key}) : super(key: key);

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final userRepo = UserRepository.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final authUser = authSnapshot.data;

        if (authUser == null) {
          return const AuthPageWidget(page: 0);
        }

        return FutureBuilder(
          future: userRepo.getUser(authUser.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = userRepo.currentUser;

            if (user == null) {
              return AuthPageWidget(
                page: 2,
                uid: authUser.uid,
              );
            }

            return const MapView();
          },
        );
      },
    );
  }
}
