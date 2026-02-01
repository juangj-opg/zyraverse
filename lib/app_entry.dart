import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/create_profile_screen.dart';
import 'features/auth/banned_screen.dart';
import 'features/rooms/room_list_screen.dart';
import 'core/services/rooms_service.dart';

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
  late final Future<void> _bootstrapFuture;

  Future<void>? _roomsSeedFuture;
  bool _validityFixDone = false;

  @override
  void initState() {
    super.initState();
    _userRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
    _bootstrapFuture = _bootstrapUserDoc();
  }

  Future<void> _bootstrapUserDoc() async {
    final firestore = FirebaseFirestore.instance;

    await firestore.runTransaction((tx) async {
      final snap = await tx.get(_userRef);

      if (!snap.exists) {
        tx.set(_userRef, {
          'uid': widget.user.uid,
          'email': widget.user.email,
          'photoURL': widget.user.photoURL,
          'isValid': false,
          'isBanned': false,
          'bannedUntil': null,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'validatedAt': null,
          'username': null,
          'displayName': null,
          'bio': null,
        });
      } else {
        tx.set(_userRef, {
          'email': widget.user.email,
          'photoURL': widget.user.photoURL,
        }, SetOptions(merge: true));
      }
    });
  }

  void _fixValidityIfNeeded({
    required bool hasProfile,
    required bool isValid,
  }) {
    if (_validityFixDone) return;

    // Si ya está consistente, no hacemos nada.
    if (hasProfile == isValid) {
      _validityFixDone = true;
      return;
    }

    _validityFixDone = true;

    // Evitar writes en mitad del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userRef.set({'isValid': hasProfile}, SetOptions(merge: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, bootSnap) {
        if (bootSnap.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }

        if (bootSnap.hasError) {
          return _ErrorScaffold(
            title: 'Error preparando tu cuenta',
            message: bootSnap.error.toString(),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userRef.snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }

            if (userSnap.hasError) {
              return _ErrorScaffold(
                title: 'Error leyendo tu perfil',
                message: userSnap.error.toString(),
              );
            }

            final data = userSnap.data?.data();
            if (data == null) return const _LoadingScaffold();

            final isBanned = data['isBanned'] == true;
            final bannedUntil = data['bannedUntil'];
            final isValid = data['isValid'] == true;

            final username = (data['username'] as String?)?.trim();
            final displayName = (data['displayName'] as String?)?.trim();
            final hasProfile =
                (username != null && username.isNotEmpty) &&
                (displayName != null && displayName.isNotEmpty);

            _fixValidityIfNeeded(hasProfile: hasProfile, isValid: isValid);

            final now = DateTime.now();
            if (isBanned &&
                (bannedUntil == null ||
                    (bannedUntil as Timestamp).toDate().isAfter(now))) {
              return const BannedScreen();
            }

            // PERFIL OBLIGATORIO (tu regla exacta)
            if (!hasProfile || !isValid) {
              return const CreateProfileScreen();
            }

            // Usuario válido => seed automático de rooms
            _roomsSeedFuture ??=
                RoomsService().ensureDefaultRooms(seededByUid: widget.user.uid);

            return FutureBuilder<void>(
              future: _roomsSeedFuture,
              builder: (context, seedSnap) {
                if (seedSnap.connectionState != ConnectionState.done) {
                  return const _LoadingScaffold();
                }

                if (seedSnap.hasError) {
                  return _ErrorScaffold(
                    title: 'Error creando salas',
                    message: seedSnap.error.toString(),
                  );
                }

                return const RoomListScreen();
              },
            );
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

class _ErrorScaffold extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorScaffold({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async => FirebaseAuth.instance.signOut(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
