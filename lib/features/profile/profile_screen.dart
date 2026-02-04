import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/profile_about_section.dart';
import 'widgets/profile_collapsing_header.dart';

/// Pantalla estilo ProjectZ para ver un perfil.
/// - Misma vista para "mi perfil" y "perfil de otra persona".
/// - Por privacidad: NO se usa la foto de Google. Siempre placeholder.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profileUid,
  });

  final String profileUid;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUid != null && currentUid == profileUid;

    final userRef = FirebaseFirestore.instance.collection('users').doc(profileUid);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();

            final displayName = (data?['displayName'] as String?)?.trim();
            final username = (data?['username'] as String?)?.trim();
            final bio = (data?['bio'] as String?)?.trim();

            final shownDisplayName =
                (displayName != null && displayName.isNotEmpty) ? displayName : '---';
            final shownUsername =
                (username != null && username.isNotEmpty) ? '@$username' : '@---';

            return CustomScrollView(
              slivers: [
                ProfileCollapsingHeader(
                  displayName: shownDisplayName,
                  username: shownUsername,
                  isMe: isMe,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileAboutSection(
                          bio: (bio != null && bio.isNotEmpty) ? bio : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
