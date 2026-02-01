import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { user, system }

class Message {
  final String id;
  final MessageType type;

  // Solo para type=user
  final String? authorId;

  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    this.authorId,
  });

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    final typeRaw = (data['type'] as String?)?.toLowerCase() ?? 'user';
    final createdAtRaw = data['createdAt'];

    final created = createdAtRaw is Timestamp
        ? createdAtRaw.toDate().toLocal()
        : DateTime.fromMillisecondsSinceEpoch(0).toLocal();

    final msgType = typeRaw == 'system' ? MessageType.system : MessageType.user;

    return Message(
      id: doc.id,
      type: msgType,
      authorId: msgType == MessageType.user ? (data['authorId'] as String?) : null,
      content: (data['content'] as String?) ?? '',
      createdAt: created,
    );
  }
}
