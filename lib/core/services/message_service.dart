import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/chat/message_model.dart';

class MessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Message>> streamMessages(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

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
