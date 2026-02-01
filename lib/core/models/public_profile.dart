import 'package:cloud_firestore/cloud_firestore.dart';

class PublicProfile {
  final String uid;
  final String username;
  final String displayName;
  final String? photoURL;

  const PublicProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    this.photoURL,
  });

  factory PublicProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PublicProfile(
      uid: doc.id,
      username: (data['username'] as String?)?.trim() ?? '',
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      photoURL: (data['photoURL'] as String?)?.trim(),
    );
  }
}
