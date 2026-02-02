import 'package:cloud_firestore/cloud_firestore.dart';

class RoomsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('rooms');

  DocumentReference<Map<String, dynamic>> roomRef(String roomId) => _rooms.doc(roomId);

  DocumentReference<Map<String, dynamic>> memberRef(String roomId, String uid) =>
      _rooms.doc(roomId).collection('members').doc(uid);

  /// Salas públicas (Discover / Chats activos)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublicRooms() {
    return _rooms.where('type', isEqualTo: 'public').snapshots();
  }

  /// Mis salas (tab "Chats") basado en memberIds (arrayContains).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyRooms({required String uid}) {
    return _rooms.where('memberIds', arrayContains: uid).snapshots();
  }

  /// ¿Soy miembro de esta sala? (para habilitar input)
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyMembership({
    required String roomId,
    required String uid,
  }) {
    return memberRef(roomId, uid).snapshots();
  }

  Future<void> ensureDefaultRooms({required String seededByUid}) async {
    final now = FieldValue.serverTimestamp();

    final room1 = _rooms.doc('1');
    await room1.set({
      'name': 'TOA',
      'type': 'public',
      'ownerUid': null,
      'createdAt': now,
      'lastMessageText': null,
      'lastMessageAt': null,
      'lastActivityAt': now,
      'memberCount': 0,
      'memberIds': <String>[],
      'sortAt': 0,
      'seededBy': seededByUid,
    }, SetOptions(merge: true));
  }

  /// Unirse (idempotente) en 2 pasos.
  ///
  /// IMPORTANTE:
  /// - Primero creamos `rooms/{roomId}/members/{uid}`.
  /// - Luego (best-effort) actualizamos el doc de room.
  ///
  /// Motivo: con reglas como las tuyas, si intentas hacer ambas escrituras
  /// en una transacción, el `update` del room puede fallar porque todavía
  /// NO eres miembro (la regla usa `exists(...)` en el estado previo).
  Future<void> joinRoom({
    required String roomId,
    required String uid,
  }) async {
    final rRef = roomRef(roomId);
    final mRef = memberRef(roomId, uid);

    // 1) Si ya existe, no hacemos nada (idempotente)
    final mSnap = await mRef.get();
    if (mSnap.exists) return;

    // 2) Crear membership (esto es lo que habilita permisos de "miembro")
    await mRef.set({
      'uid': uid,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // 3) Best-effort: mantener memberIds/memberCount/actividad en el room.
    //    Si reglas lo deniegan o no hay permisos, NO rompemos el join.
    try {
      await rRef.set(
        {
          'memberIds': FieldValue.arrayUnion([uid]),
          'memberCount': FieldValue.increment(1),
          'lastActivityAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Ignorado a propósito (MVP). El usuario ya está unido igualmente.
    }
  }
}
