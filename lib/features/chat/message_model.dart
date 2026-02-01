import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { user, system }

class MessageModel {
  final String id;
  final MessageType type;

  final String? authorId;
  final String? authorDisplayName;

  final String text;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.type,
    required this.text,
    required this.createdAt,
    this.authorId,
    this.authorDisplayName,
  });

  bool get isSystem => type == MessageType.system;

  static MessageType _parseType(dynamic v) {
    final s = (v ?? 'user').toString();
    return s == 'system' ? MessageType.system : MessageType.user;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    // Cuando aún no ha llegado serverTimestamp:
    return DateTime.now();
  }

  factory MessageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MessageModel(
      id: doc.id,
      type: _parseType(data['type']),
      authorId: data['authorId']?.toString(),
      authorDisplayName: data['authorDisplayName']?.toString(),
      text: (data['text'] ?? '').toString(),
      createdAt: _parseDate(data['createdAt']),
    );
  }
}
