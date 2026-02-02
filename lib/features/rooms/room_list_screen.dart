import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import '../chat/chat_screen.dart';
import 'room_model.dart';

class RoomListScreen extends StatelessWidget {
  final bool embedded;

  const RoomListScreen({super.key, this.embedded = false});

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

  List<Room> _sortedRooms(List<Room> rooms) {
    rooms.sort((a, b) {
      final aTime = a.lastActivityAt ?? a.createdAt;
      final bTime = b.lastActivityAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return rooms;
  }

  Widget _buildList(BuildContext context) {
    final service = RoomsService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('No has iniciado sesión'));
    }

    return StreamBuilder<List<String>>(
      stream: service.watchMyRoomIds(uid: uid),
      builder: (context, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (idsSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error cargando tus salas: ${idsSnap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final roomIds = idsSnap.data ?? const <String>[];
        if (roomIds.isEmpty) {
          return const Center(
            child: Text(
              'No hay salas',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // Nota: `whereIn` tiene límite de 10.
        if (roomIds.length <= 10) {
          final query = FirebaseFirestore.instance
              .collection('rooms')
              .where(FieldPath.documentId, whereIn: roomIds);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, roomsSnap) {
              if (roomsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (roomsSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error cargando tus salas: ${roomsSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final docs = roomsSnap.data?.docs ?? [];
              final rooms = _sortedRooms(docs.map((d) => Room.fromFirestore(d)).toList());

              return _RoomsListView(
                rooms: rooms,
                formatRelative: _formatRelative,
              );
            },
          );
        }

        // Fallback si hay demasiadas salas: las cargamos una vez.
        return FutureBuilder<List<Room>>(
          future: _loadRoomsOnce(roomIds),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error cargando tus salas: ${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final rooms = _sortedRooms(snap.data ?? []);
            if (rooms.isEmpty) {
              return const Center(child: Text('No hay salas'));
            }

            return _RoomsListView(
              rooms: rooms,
              formatRelative: _formatRelative,
            );
          },
        );
      },
    );
  }

  Future<List<Room>> _loadRoomsOnce(List<String> ids) async {
    final roomsCol = FirebaseFirestore.instance.collection('rooms');
    final snaps = await Future.wait(ids.map((id) => roomsCol.doc(id).get()));
    return snaps
        .where((d) => d.exists)
        .map((d) => Room.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _MyChatsTitle(),
            SizedBox(height: 12),
            Expanded(child: _MyChatsBody()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
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
      body: _buildList(context),
    );
  }
}

class _MyChatsTitle extends StatelessWidget {
  const _MyChatsTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Text(
            'Mis chats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ),
        Icon(Icons.chevron_right, color: Colors.white54),
      ],
    );
  }
}

class _MyChatsBody extends StatelessWidget {
  const _MyChatsBody();

  @override
  Widget build(BuildContext context) {
    final service = RoomsService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('No has iniciado sesión'));
    }

    String formatRelative(DateTime? dt) {
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

    List<Room> sorted(List<Room> rooms) {
      rooms.sort((a, b) {
        final aTime = a.lastActivityAt ?? a.createdAt;
        final bTime = b.lastActivityAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return rooms;
    }

    Future<List<Room>> loadOnce(List<String> ids) async {
      final roomsCol = FirebaseFirestore.instance.collection('rooms');
      final snaps = await Future.wait(ids.map((id) => roomsCol.doc(id).get()));
      return snaps
          .where((d) => d.exists)
          .map((d) => Room.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    }

    return StreamBuilder<List<String>>(
      stream: service.watchMyRoomIds(uid: uid),
      builder: (context, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (idsSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error cargando tus salas: ${idsSnap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final roomIds = idsSnap.data ?? const <String>[];
        if (roomIds.isEmpty) {
          return const Center(
            child: Text(
              'No hay salas',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        if (roomIds.length <= 10) {
          final query = FirebaseFirestore.instance
              .collection('rooms')
              .where(FieldPath.documentId, whereIn: roomIds);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, roomsSnap) {
              if (roomsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (roomsSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error cargando tus salas: ${roomsSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final docs = roomsSnap.data?.docs ?? [];
              final rooms = sorted(docs.map((d) => Room.fromFirestore(d)).toList());

              return _RoomsListView(
                rooms: rooms,
                formatRelative: formatRelative,
              );
            },
          );
        }

        return FutureBuilder<List<Room>>(
          future: loadOnce(roomIds),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error cargando tus salas: ${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final rooms = sorted(snap.data ?? []);
            if (rooms.isEmpty) {
              return const Center(child: Text('No hay salas'));
            }

            return _RoomsListView(
              rooms: rooms,
              formatRelative: formatRelative,
            );
          },
        );
      },
    );
  }
}

class _RoomsListView extends StatelessWidget {
  final List<Room> rooms;
  final String Function(DateTime?) formatRelative;

  const _RoomsListView({
    required this.rooms,
    required this.formatRelative,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 0),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final room = rooms[index];

        final chipText = room.type == RoomType.public ? 'Público' : 'Privado';
        final lastTime = formatRelative(room.lastActivityAt);
        final preview = (room.lastMessageText?.trim().isNotEmpty == true)
            ? room.lastMessageText!.trim()
            : 'Sin mensajes aún';

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            child: Row(
              children: [
                // Placeholder imagen sala
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                ),
                const SizedBox(width: 12),

                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Línea 1: chip + título + tiempo derecha
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              chipText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              room.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            lastTime,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Línea 2: último mensaje (una línea)
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
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
  }
}
