import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String name;
  final RoomType type;
  final int membersCount;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.name,
    required this.type,
    required this.membersCount,
    required this.createdAt,
  });

  factory Room.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final typeRaw = (data['type'] as String?)?.toLowerCase() ?? 'public';
    final membersCountRaw = data['membersCount'];
    final createdAtRaw = data['createdAt'];

    return Room(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Sala ${doc.id}',
      type: typeRaw == 'group' ? RoomType.group : RoomType.public,
      membersCount: membersCountRaw is int
          ? membersCountRaw
          : (membersCountRaw is num ? membersCountRaw.toInt() : 0),
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

enum RoomType {
  public,
  group,
}
