import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomType { public, private }

class Room {
  final String id;
  final String name;
  final String? description;
  final RoomType type;

  final DateTime createdAt;
  final DateTime sortAt;

  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  const Room({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.sortAt,
    this.description,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  static DateTime _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _tsToDateNullable(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  static RoomType _parseType(dynamic v) {
    final s = (v is String) ? v : 'public';
    return s == 'private' ? RoomType.private : RoomType.public;
  }

  factory Room.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = _tsToDate(data['createdAt']);
    final sortAt = data['sortAt'] != null ? _tsToDate(data['sortAt']) : createdAt;

    return Room(
      id: doc.id,
      name: (data['name'] as String?) ?? '(sin nombre)',
      description: data['description'] as String?,
      type: _parseType(data['type']),
      createdAt: createdAt,
      sortAt: sortAt,
      lastMessagePreview: data['lastMessagePreview'] as String?,
      lastMessageAt: _tsToDateNullable(data['lastMessageAt']),
    );
  }
}
