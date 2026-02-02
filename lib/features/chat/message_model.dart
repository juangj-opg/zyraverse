import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;

  /// 'user' | 'system'
  final String type;

  final String authorId;
  final String authorDisplayName;

  /// Texto del mensaje (compatibilidad con `content`)
  final String text;

  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.type,
    required this.authorId,
    required this.authorDisplayName,
    required this.text,
    required this.createdAt,
  });

  String get content => text;

  bool get isSystem => type == 'system';

  static DateTime _parseCreatedAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();

    // ✅ Evita el 1970 por serverTimestamp aún no resuelto
    return DateTime.now();
  }

  static MessageModel _from(String id, Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.trim();
    final authorId = (data['authorId'] as String?)?.trim();

    final authorDisplayName =
        (data['authorDisplayName'] as String?)?.trim() ??
        (data['displayName'] as String?)?.trim() ??
        '';

    final text =
        (data['text'] as String?) ??
        (data['content'] as String?) ?? // compat
        '';

    final createdAt = _parseCreatedAt(data['createdAt']);

    return MessageModel(
      id: id,
      type: (type == null || type.isEmpty) ? 'user' : type,
      authorId: authorId ?? '',
      authorDisplayName: authorDisplayName,
      text: text,
      createdAt: createdAt,
    );
  }

  factory MessageModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _from(doc.id, doc.data());
  }

  factory MessageModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return _from(doc.id, doc.data() ?? <String, dynamic>{});
  }
}

typedef Message = MessageModel;
