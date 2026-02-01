import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'features/auth/login_screen.dart';
import 'features/rooms/room_list_screen.dart';

class ZyraVerseApp extends StatelessWidget {
  const ZyraVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZyraVerse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const RoomListScreen();
          }

          return LoginScreen();
        },
      ),
    );
  }
}
