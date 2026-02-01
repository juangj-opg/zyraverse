import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/create_profile_screen.dart';
import 'features/auth/banned_screen.dart';
import 'features/rooms/room_list_screen.dart';

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

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

        if (!authSnapshot.hasData) {
          return LoginScreen();
        }

        final user = authSnapshot.data!;
        final uid = user.uid;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return FutureBuilder(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .set({
                  'uid': uid,
                  'email': user.email,
                  'photoURL': user.photoURL,
                  'isValid': false,
                  'isBanned': false,
                  'bannedUntil': null,
                  'role': 'user',
                  'createdAt': FieldValue.serverTimestamp(),
                  'validatedAt': null,
                }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const CreateProfileScreen();
                },
              );
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>;

            final isValid = data['isValid'] == true;
            final isBanned = data['isBanned'] == true;
            final bannedUntil = data['bannedUntil'];

            if (isBanned &&
                (bannedUntil == null ||
                    (bannedUntil as Timestamp)
                        .toDate()
                        .isAfter(DateTime.now()))) {
              return const BannedScreen();
            }

            if (!isValid) {
              return const CreateProfileScreen();
            }

            return const RoomListScreen();
          },
        );
      },
    );
  }
}
