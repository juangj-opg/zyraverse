import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String roomId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final timestamp = data['createdAt'];

    return Message(
      id: id,
      roomId: data['roomId'] as String,
      authorId: data['authorId'] as String,
      content: data['content'] as String,
      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
