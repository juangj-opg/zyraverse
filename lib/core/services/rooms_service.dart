import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/rooms/room_model.dart';

class RoomsService {
  RoomsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  DocumentReference<Map<String, dynamic>> roomRef(String roomId) =>
      _rooms.doc(roomId);

  CollectionReference<Map<String, dynamic>> membersRef(String roomId) =>
      roomRef(roomId).collection('members');

  Stream<List<RoomModel>> watchRooms() {
    // Requiere que los docs tengan sortAt (si no, igualmente suele funcionar, pero mejor tenerlo)
    return _rooms.orderBy('sortAt', descending: true).snapshots().map((snap) {
      return snap.docs.map(RoomModel.fromDoc).toList();
    });
  }

  Stream<RoomModel?> watchRoom(String roomId) {
    return roomRef(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RoomModel.fromDoc(doc);
    });
  }

  Stream<bool> watchIsMember(String roomId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return membersRef(roomId).doc(uid).snapshots().map((d) => d.exists);
  }

  Stream<int> watchMembersCount(String roomId) {
    return roomRef(roomId).snapshots().map((d) {
      final data = d.data();
      final v = data?['membersCount'];
      return (v is num) ? v.toInt() : 0;
    });
  }

  Stream<int> watchMembersPreviewCount(String roomId, {int limit = 3}) {
    return membersRef(roomId)
        .orderBy('joinedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> ensureRoomBaseFields(String roomId) async {
    // Si la sala ya existe, merge. Si no, la crea mínima (modo dev).
    await roomRef(roomId).set({
      'sortAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'membersCount': FieldValue.increment(0),
      'lastMessageText': 'Sin mensajes aún',
    }, SetOptions(merge: true));
  }

  Future<void> joinRoom({
    required String roomId,
    required String displayName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No autenticado');

    final memberDoc = membersRef(roomId).doc(uid);

    await _db.runTransaction((tx) async {
      final memberSnap = await tx.get(memberDoc);

      if (!memberSnap.exists) {
        tx.set(memberDoc, {
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'member',
        });

        tx.set(roomRef(roomId), {
          'membersCount': FieldValue.increment(1),
          'sortAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    // Mensaje system: lo manda MessageService (desde UI), aquí solo unión.
  }

  Future<void> leaveRoom({
    required String roomId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No autenticado');

    final memberDoc = membersRef(roomId).doc(uid);

    await _db.runTransaction((tx) async {
      final memberSnap = await tx.get(memberDoc);

      if (memberSnap.exists) {
        tx.delete(memberDoc);
        tx.set(roomRef(roomId), {
          'membersCount': FieldValue.increment(-1),
          'sortAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }
}
