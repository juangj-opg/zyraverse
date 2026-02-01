import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String authorId;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    final createdAtRaw = data['createdAt'];

    return Message(
      id: doc.id,
      authorId: data['authorId'] as String,
      content: data['content'] as String,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
