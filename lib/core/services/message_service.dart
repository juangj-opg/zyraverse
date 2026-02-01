import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/chat/message_model.dart';

class MessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Escucha mensajes en tiempo real de una sala
  Stream<List<Message>> streamMessages(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Message(
          id: doc.id,
          roomId: roomId,
          authorId: data['authorId'] ?? 'unknown',
          content: data['content'] ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
        );
      }).toList();
    });
  }

  /// Envía un mensaje a Firestore
  Future<void> sendMessage({
    required String roomId,
    required String authorId,
    required String content,
  }) async {
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add({
      'authorId': authorId,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
