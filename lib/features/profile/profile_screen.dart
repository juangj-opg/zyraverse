import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/profile_about_section.dart';
import 'widgets/profile_collapsing_header.dart';

/// Pantalla estilo ProjectZ para ver un perfil.
/// - Misma vista para "mi perfil" y "perfil de otra persona".
/// - Por privacidad: NO se usa la foto de Google. Siempre placeholder.
///
/// Importante (comportamiento ProjectZ):
/// - La barra superior (flecha + "...") siempre está.
/// - El título reducido (mini avatar + nombre) SOLO aparece cuando "Sobre mí"
///   llega arriba del todo.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profileUid,
  });

  final String profileUid;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _aboutKey = GlobalKey();

  bool _showCollapsedTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Primera medición tras el primer layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCollapsedTitle());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateCollapsedTitle();
  }

  void _updateCollapsedTitle() {
    final ctx = _aboutKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject();
    if (box is! RenderBox) return;

    // Posición del inicio del bloque "Sobre mí".
    final dy = box.localToGlobal(Offset.zero).dy;

    // Como el body está dentro de SafeArea, el SliverAppBar pinned se queda en kToolbarHeight.
    final threshold = kToolbarHeight + 2;

    final shouldShow = dy <= threshold;
    if (shouldShow != _showCollapsedTitle) {
      setState(() => _showCollapsedTitle = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUid != null && currentUid == widget.profileUid;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(widget.profileUid);

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
                (displayName != null && displayName.isNotEmpty)
                    ? displayName
                    : '---';
            final shownUsername = (username != null && username.isNotEmpty)
                ? '@$username'
                : '@---';

            // Recalcular tras rebuilds de stream (por si cambia altura/posiciones).
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _updateCollapsedTitle());

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                ProfileCollapsingHeader(
                  displayName: shownDisplayName,
                  username: shownUsername,
                  isMe: isMe,
                  showCollapsedTitle: _showCollapsedTitle,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Key del bloque "Sobre mí" para saber cuándo toca arriba.
                        KeyedSubtree(
                          key: _aboutKey,
                          child: ProfileAboutSection(
                            bio: (bio != null && bio.isNotEmpty) ? bio : null,
                          ),
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
