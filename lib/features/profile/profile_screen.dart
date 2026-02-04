import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/profile_about_section.dart';
import 'widgets/profile_collapsing_header.dart';

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

  // ✅ La key debe estar en el HEADER "Sobre mí" (el pinned),
  // no dentro del contenido, porque es lo que queremos “detectar” cuando llega arriba.
  final GlobalKey _aboutHeaderKey = GlobalKey();

  bool _showCollapsedTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCollapsedTitle());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() => _updateCollapsedTitle();

  void _updateCollapsedTitle() {
    if (!mounted) return;

    final ctx = _aboutHeaderKey.currentContext;
    if (ctx == null) return;

    final obj = ctx.findRenderObject();
    if (obj is! RenderBox) return;

    // Posición global del header "Sobre mí"
    final dy = obj.localToGlobal(Offset.zero).dy;

    // ✅ Umbral correcto en iOS (notch): SafeArea desplaza el contenido,
    // así que hay que sumar el padding superior real.
    final topPadding = MediaQuery.of(context).padding.top;
    final threshold = topPadding + kToolbarHeight + 2;

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

            // Recalcular tras rebuilds del stream.
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

                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // ✅ "Sobre mí" ANCLADO (pinned) estilo ProjectZ
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedSectionHeaderDelegate(
                    child: KeyedSubtree(
                      key: _aboutHeaderKey,
                      child: const _PinnedSectionHeader(title: 'Sobre mí'),
                    ),
                  ),
                ),

                // Contenido de "Sobre mí" (Bio card)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    child: ProfileAboutSection(
                      bio: (bio != null && bio.isNotEmpty) ? bio : null,
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

class _PinnedSectionHeader extends StatelessWidget {
  const _PinnedSectionHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    // Fondo opaco para que el contenido pase por detrás y se lea perfecto.
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.black.withOpacity(0.90),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PinnedSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedSectionHeaderDelegate({
    required this.child,
  });

  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedSectionHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
