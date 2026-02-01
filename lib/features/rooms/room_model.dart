import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String name; // "TOA"
  final String type; // "public" | "private"
  final String? ownerId;

  final int membersCount;

  final String lastMessageText;
  final DateTime? lastMessageAt;

  const RoomModel({
    required this.id,
    required this.name,
    required this.type,
    required this.membersCount,
    required this.lastMessageText,
    required this.lastMessageAt,
    this.ownerId,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  factory RoomModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final mc = data['membersCount'];
    final membersCount = mc is num ? mc.toInt() : 0;

    return RoomModel(
      id: doc.id,
      name: (data['name'] ?? 'Sala').toString(),
      type: (data['type'] ?? 'public').toString(),
      ownerId: data['ownerId']?.toString(),
      membersCount: membersCount,
      lastMessageText: (data['lastMessageText'] ?? 'Sin mensajes aún').toString(),
      lastMessageAt: _parseDate(data['lastMessageAt']),
    );
  }

  String get typeLabel => type == 'private' ? 'Privada' : 'Pública';
  bool get isPublic => type != 'private';
}
