import 'package:cloud_firestore/cloud_firestore.dart';

class RoomsService {
  final FirebaseFirestore _db;

  RoomsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Crea rooms por defecto si no existen.
  /// Idempotente: si ya existen, no toca nada.
  Future<void> ensureDefaultRooms({required String seededByUid}) async {
    final defaults = <Map<String, dynamic>>[
      {
        'id': '1',
        'name': 'Rol Fantasía',
        'description': 'Sala pública para rol',
        'type': 'public',
      },
    ];

    await _db.runTransaction((tx) async {
      for (final r in defaults) {
        final id = r['id'] as String;
        final ref = _db.collection('rooms').doc(id);
        final snap = await tx.get(ref);

        if (!snap.exists) {
          tx.set(ref, {
            'name': r['name'],
            'description': r['description'],
            'type': r['type'],
            'createdAt': FieldValue.serverTimestamp(),
            'sortAt': FieldValue.serverTimestamp(),
            'createdBy': seededByUid,
            'lastMessagePreview': '',
            'lastMessageAt': null,
          });
        }
      }
    });
  }
}
