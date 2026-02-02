import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import '../chat/chat_screen.dart';
import '../rooms/room_model.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  List<Room> _sortedRooms(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final rooms = docs.map((d) => Room.fromFirestore(d)).toList();

    rooms.sort((a, b) {
      final aTime = a.lastActivityAt ?? a.createdAt;
      final bTime = b.lastActivityAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return rooms;
  }

  String _formatRelative(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';

    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    final service = RoomsService();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchPublicRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error cargando chats activos: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay salas públicas todavía',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final rooms = _sortedRooms(docs);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título sección (estilo ProjectZ)
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Chats activos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final memberCount = room.memberCount ?? 0;
                    final last = _formatRelative(room.lastActivityAt);

                    return _ActiveChatCard(
                      title: room.name,
                      subtitle: last.isNotEmpty ? last : 'Nuevo',
                      memberCount: memberCount,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveChatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int memberCount;
  final VoidCallback onTap;

  const _ActiveChatCard({
    required this.title,
    required this.subtitle,
    required this.memberCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            // Imagen placeholder
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Container(
                  width: double.infinity,
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: Colors.white38, size: 34),
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            '$memberCount',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
  }
}
