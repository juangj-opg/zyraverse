import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import '../chat/chat_screen.dart';
import 'room_model.dart';

class RoomListScreen extends StatelessWidget {
  RoomListScreen({super.key});

  final RoomsService _roomsService = RoomsService();

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';

    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text('ZyraVerse'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Crear sala: pendiente')),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<RoomModel>>(
        stream: _roomsService.watchRooms(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error cargando salas: ${snap.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snap.data!;
          if (rooms.isEmpty) {
            return const Center(
              child: Text('No hay salas aún', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1A1A22)),
            itemBuilder: (context, i) {
              final room = rooms[i];
              final time = _relativeTime(room.lastMessageAt);

              return InkWell(
                onTap: () async {
                  // Garantizamos campos base por si la sala está vieja
                  await _roomsService.ensureRoomBaseFields(room.id);

                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatScreen(roomId: room.id)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF1C1C26),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    room.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (time.isNotEmpty)
                                  Text(time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              room.lastMessageText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _chip(room.typeLabel),
                                const SizedBox(width: 8),
                                Text(
                                  'Miembros: ${room.membersCount}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
