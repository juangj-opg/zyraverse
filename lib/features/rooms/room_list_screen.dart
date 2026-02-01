import 'package:flutter/material.dart';
import '../chat/chat_screen.dart';
import 'room_model.dart';

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rooms = [
      Room(
        id: '1',
        name: 'Rol Fantasía',
        type: RoomType.public,
        createdAt: DateTime.now(),
      ),
      Room(
        id: '2',
        name: 'Cyberpunk',
        type: RoomType.public,
        createdAt: DateTime.now(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ZyraVerse')),
      body: ListView.builder(
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return ListTile(
            title: Text(room.name),
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
      ),
    );
  }
}
