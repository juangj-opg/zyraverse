import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo único para mensajes.
/// - Lee tanto el esquema nuevo (`text`, `authorDisplayName`)
///   como el antiguo (`content`) por compatibilidad.
class MessageModel {
  final String id;

  /// 'user' | 'system' (por ahora)
  final String type;

  /// Para system puede venir vacío.
  final String authorId;

  /// Para system puede venir vacío.
  final String authorDisplayName;

  /// Texto del mensaje (equivalente a `content` antiguo)
  final String text;

  /// Fecha estimada (si llega null por serverTimestamp pendiente)
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.type,
    required this.authorId,
    required this.authorDisplayName,
    required this.text,
    required this.createdAt,
  });

  /// Compatibilidad con código viejo que usaba `content`.
  String get content => text;

  bool get isSystem => type == 'system';

  static DateTime _parseCreatedAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    // Si aún no ha resuelto serverTimestamp, evitamos nulls.
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static MessageModel _from(String id, Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.trim();
    final authorId = (data['authorId'] as String?)?.trim();
    final authorDisplayName =
        (data['authorDisplayName'] as String?)?.trim() ??
        (data['displayName'] as String?)?.trim(); // fallback

    final text =
        (data['text'] as String?) ??
        (data['content'] as String?) ?? // fallback esquema antiguo
        '';

    final createdAt = _parseCreatedAt(data['createdAt']);

    return MessageModel(
      id: id,
      type: (type == null || type.isEmpty) ? 'user' : type,
      authorId: authorId ?? '',
      authorDisplayName: authorDisplayName ?? '',
      text: text,
      createdAt: createdAt,
    );
  }

  factory MessageModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _from(doc.id, doc.data());
  }

  factory MessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return _from(doc.id, data);
  }
}

/// Alias para no romper imports/código antiguo que usa `Message`.
typedef Message = MessageModel;
