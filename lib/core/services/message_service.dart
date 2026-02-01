import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/chat/message_model.dart';

class MessageService {
  MessageService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) =>
      _db.collection('rooms').doc(roomId);

  CollectionReference<Map<String, dynamic>> _messagesRef(String roomId) =>
      _roomRef(roomId).collection('messages');

  Stream<List<MessageModel>> watchMessages(String roomId) {
    return _messagesRef(roomId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(MessageModel.fromDoc).toList());
  }

  Future<void> sendUserMessage({
    required String roomId,
    required String text,
    required String authorDisplayName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No autenticado');

    final now = FieldValue.serverTimestamp();
    final msgDoc = _messagesRef(roomId).doc();

    final batch = _db.batch();

    batch.set(msgDoc, {
      'type': 'user',
      'authorId': uid,
      'authorDisplayName': authorDisplayName,
      'text': text,
      'createdAt': now,
    });

    batch.set(_roomRef(roomId), {
      'lastMessageText': text,
      'lastMessageAt': now,
      'sortAt': now,
      'createdAt': now,
      'membersCount': FieldValue.increment(0),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> sendSystemMessage({
    required String roomId,
    required String text,
  }) async {
    final now = FieldValue.serverTimestamp();
    final msgDoc = _messagesRef(roomId).doc();

    final batch = _db.batch();

    batch.set(msgDoc, {
      'type': 'system',
      'text': text,
      'createdAt': now,
    });

    batch.set(_roomRef(roomId), {
      'lastMessageText': text,
      'lastMessageAt': now,
      'sortAt': now,
      'createdAt': now,
      'membersCount': FieldValue.increment(0),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
