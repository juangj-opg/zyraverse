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
          return const _LoadingScaffold();
        }

        final user = authSnapshot.data;
        if (user == null) return const LoginScreen();

        return _UserGate(user: user);
      },
    );
  }
}

class _UserGate extends StatefulWidget {
  final User user;

  const _UserGate({required this.user});

  @override
  State<_UserGate> createState() => _UserGateState();
}

class _UserGateState extends State<_UserGate> {
  late final DocumentReference<Map<String, dynamic>> _userRef;
  late final Future<void> _ensureUserDocFuture;

  @override
  void initState() {
    super.initState();
    _userRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
    _ensureUserDocFuture = _ensureUserDoc();
  }

  Future<void> _ensureUserDoc() async {
    final snap = await _userRef.get();
    if (snap.exists) return;

    await _userRef.set({
      'uid': widget.user.uid,
      'email': widget.user.email,
      'photoURL': widget.user.photoURL,
      'isValid': false,
      'isBanned': false,
      'bannedUntil': null,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'validatedAt': null,
      // opcional: campos de perfil para que “perfil creado” sea inequívoco
      'username': null,
      'displayName': null,
      'bio': null,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ensureUserDocFuture,
      builder: (context, ensureSnap) {
        if (ensureSnap.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userRef.snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }

            final data = userSnapshot.data?.data();
            if (data == null) {
              // caso raro: doc borrado / permisos / race
              return const _LoadingScaffold();
            }

            final isBanned = data['isBanned'] == true;
            final bannedUntil = data['bannedUntil'];
            final isValid = data['isValid'] == true;

            final hasProfile =
                (data['username'] as String?)?.isNotEmpty == true &&
                (data['displayName'] as String?)?.isNotEmpty == true;

            final now = DateTime.now();

            if (isBanned &&
                (bannedUntil == null ||
                    (bannedUntil as Timestamp).toDate().isAfter(now))) {
              return const BannedScreen();
            }

            // Lo que pedías:
            // - Si NO tiene perfil creado o NO es válido -> CreateProfileScreen
            if (!hasProfile || !isValid) {
              return const CreateProfileScreen();
            }

            return const RoomListScreen();
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
