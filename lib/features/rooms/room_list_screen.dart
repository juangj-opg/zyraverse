import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../chat/chat_screen.dart';
import '../auth/create_profile_screen.dart';
import 'room_model.dart';

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key});

  bool _isPermissionDenied(Object? e) {
    if (e == null) return false;
    final s = e.toString().toLowerCase();
    return s.contains('permission-denied') || s.contains('permission denied');
  }

  @override
  Widget build(BuildContext context) {
    final roomsRef = FirebaseFirestore.instance.collection('rooms');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZyraVerse'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: roomsRef.orderBy('sortAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            if (_isPermissionDenied(snapshot.error)) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Acceso restringido',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Necesitas completar tu perfil (username y nombre visible) para ver las salas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateProfileScreen()),
                          );
                        },
                        child: const Text('Completar perfil'),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay salas'));
          }

          final rooms = snapshot.data!.docs.map((d) => Room.fromFirestore(d)).toList();

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final subtitle = (room.lastMessagePreview ?? room.description ?? '').trim();

              return ListTile(
                title: Text(room.name),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
