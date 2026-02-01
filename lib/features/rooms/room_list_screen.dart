import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import 'room_model.dart';

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roomsRef = FirebaseFirestore.instance.collection('rooms');

    return Scaffold(
      appBar: AppBar(title: const Text('ZyraVerse')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: roomsRef.orderBy('createdAt', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error cargando salas'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No hay salas'));
          }

          final rooms = docs.map((d) => Room.fromFirestore(d)).toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final subtitle = room.type == RoomType.public ? 'Pública' : 'Grupo';

              return ListTile(
                title: Text(room.name),
                subtitle: Text('$subtitle · Miembros: ${room.membersCount}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(room: room),
                    ),
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
