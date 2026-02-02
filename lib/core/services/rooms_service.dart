import 'package:cloud_firestore/cloud_firestore.dart';

class RoomsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('rooms');

  DocumentReference<Map<String, dynamic>> roomRef(String roomId) => _rooms.doc(roomId);

  DocumentReference<Map<String, dynamic>> memberRef(String roomId, String uid) =>
      _rooms.doc(roomId).collection('members').doc(uid);

  /// Stream de salas ordenadas por última actividad (sin índices raros)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms() {
    return _rooms.orderBy('lastActivityAt', descending: true).snapshots();
  }

  /// Stream de salas públicas.
  ///
  /// Nota: evitamos mezclar `where(type==public)` con `orderBy(lastActivityAt)`
  /// para no forzar índices compuestos en desarrollo.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublicRooms() {
    return _rooms.where('type', isEqualTo: 'public').snapshots();
  }

  /// Stream de los IDs de salas donde el usuario es miembro.
  ///
  /// Usamos `collectionGroup('members')` porque la membresía cuelga de cada sala:
  /// rooms/{roomId}/members/{uid}
  ///
  /// Nota: aquí asumimos que el docId del miembro es el UID del usuario.
  Stream<List<String>> watchMyRoomIds({required String uid}) {
    return _db
        .collectionGroup('members')
        .where(FieldPath.documentId, isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final ids = <String>[];
      for (final d in snap.docs) {
        final roomRef = d.reference.parent.parent;
        if (roomRef != null) ids.add(roomRef.id);
      }
      return ids;
    });
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
