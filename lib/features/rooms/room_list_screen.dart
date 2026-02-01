import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        stream: roomsRef.orderBy('sortAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay salas'));
          }

          final rooms = snapshot.data!.docs
              .map((d) => Room.fromFirestore(d))
              .toList();

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final room = rooms[index];

              final subtitle = (room.lastMessagePreview != null &&
                      room.lastMessagePreview!.trim().isNotEmpty)
                  ? room.lastMessagePreview!
                  : (room.description ?? '');

              return ListTile(
                title: Text(room.name),
                subtitle: subtitle.trim().isEmpty ? null : Text(subtitle),
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
