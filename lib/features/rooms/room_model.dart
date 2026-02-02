import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomType { public, private }

class Room {
  final String id;
  final String name;
  final RoomType type;

  final DateTime createdAt;

  // Para el listado estilo ProjectZ
  final String? lastMessageText;
  final DateTime? lastActivityAt;

  // Para header del chat (miembros)
  final int? memberCount;

  const Room({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.lastMessageText,
    this.lastActivityAt,
    this.memberCount,
  });

  factory Room.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final createdAtRaw = data['createdAt'];
    final lastActivityRaw = data['lastActivityAt'];

    return Room(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Sala',
      type: ((data['type'] as String?) ?? 'public') == 'private'
          ? RoomType.private
          : RoomType.public,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      lastMessageText: data['lastMessageText'] as String?,
      lastActivityAt: lastActivityRaw is Timestamp
          ? lastActivityRaw.toDate()
          : null,
      memberCount: (data['memberCount'] is int) ? data['memberCount'] as int : null,
    );
  }
}
