import 'package:cloud_firestore/cloud_firestore.dart';

class RoomsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  DocumentReference<Map<String, dynamic>> roomRef(String roomId) =>
      _rooms.doc(roomId);

  DocumentReference<Map<String, dynamic>> memberRef(String roomId, String uid) =>
      _rooms.doc(roomId).collection('members').doc(uid);

  /// Stream de salas ordenadas por última actividad (sin índices raros)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms() {
    return _rooms.orderBy('lastActivityAt', descending: true).snapshots();
  }

  /// Crea/asegura salas por defecto (prototipo)
  Future<void> ensureDefaultRooms({required String seededByUid}) async {
    final now = FieldValue.serverTimestamp();

    // Sala 1: TOA (tu ejemplo)
    final room1 = _rooms.doc('1');
    await room1.set({
      'name': 'TOA',
      'type': 'public',
      'ownerUid': null, // pendiente
      'createdAt': now,
      'lastMessageText': null,
      'lastMessageAt': null,
      'lastActivityAt': now,
      'memberCount': 0,
      'sortAt': 0, // lo conservas para futuro
      'seededBy': seededByUid,
    }, SetOptions(merge: true));
  }

  /// Stream: ¿soy miembro?
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyMembership({
    required String roomId,
    required String uid,
  }) {
    return memberRef(roomId, uid).snapshots();
  }

  /// Unirse como miembro (idempotente) + incrementar contador
  Future<void> joinRoom({
    required String roomId,
    required String uid,
  }) async {
    final rRef = roomRef(roomId);
    final mRef = memberRef(roomId, uid);

    await _db.runTransaction((tx) async {
      final mSnap = await tx.get(mRef);

      if (mSnap.exists) {
        // ya es miembro
        return;
      }

      tx.set(mRef, {
        'uid': uid,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        rRef,
        {'memberCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    });
  }
}
