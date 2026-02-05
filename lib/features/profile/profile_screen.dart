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
  static const double _expandedHeaderHeight = 300;
  static const double _sheetTopRadius = 28;
  static const Color _sheetBg = Color(0xFF0F0F12);

  final ScrollController _scrollController = ScrollController();
  bool _showCollapsedTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recomputeCollapsedTitle();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() => _recomputeCollapsedTitle();

  void _setCollapsedTitle(bool value) {
    if (!mounted) return;
    if (value == _showCollapsedTitle) return;
    setState(() => _showCollapsedTitle = value);
  }

  void _recomputeCollapsedTitle() {
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      _setCollapsedTitle(false);
      return;
    }

    final offset = _scrollController.offset;

    if (offset <= 1.0) {
      _setCollapsedTitle(false);
      return;
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final collapseDistance =
        _expandedHeaderHeight - (kToolbarHeight + topPadding);

    const extra = 12.0;
    final threshold = (collapseDistance - extra).clamp(0.0, double.infinity);

    _setCollapsedTitle(offset >= threshold);
  }

  Future<void> _snapUpAfterCollapse() async {
    if (!_scrollController.hasClients) return;

    final target = _scrollController.offset.clamp(0.0, 120.0);
    if ((_scrollController.offset - target).abs() < 0.5) {
      _recomputeCollapsedTitle();
      return;
    }

    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );

    _recomputeCollapsedTitle();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUid != null && currentUid == widget.profileUid;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(widget.profileUid);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _recomputeCollapsedTitle();
          });

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              ProfileCollapsingHeader(
                displayName: shownDisplayName,
                username: shownUsername,
                isMe: isMe,
                showCollapsedTitle: _showCollapsedTitle,
              ),

              // Inicio del “sheet” con radio superior.
              SliverToBoxAdapter(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(_sheetTopRadius),
                    topRight: Radius.circular(_sheetTopRadius),
                  ),
                  child: Container(
                    color: _sheetBg,
                    height: 14,
                  ),
                ),
              ),

              // Header pinned "Sobre mí" con radio cuando está al inicio.
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedSectionHeaderDelegate(
                  title: 'Sobre mí',
                  bg: _sheetBg,
                  topRadius: _sheetTopRadius,
                ),
              ),

              // ✅ Rellenar todo el resto de pantalla con el fondo de “Sobre mí”.
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  color: _sheetBg,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  alignment: Alignment.topLeft,
                  child: ProfileAboutSection(
                    bio: (bio != null && bio.isNotEmpty) ? bio : null,
                    onCollapseSnapToTop: _snapUpAfterCollapse,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PinnedSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedSectionHeaderDelegate({
    required this.title,
    required this.bg,
    required this.topRadius,
  });

  final String title;
  final Color bg;
  final double topRadius;

  static const double _h = 52;

  @override
  double get minExtent => _h;

  @override
  double get maxExtent => _h;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final radius = overlapsContent
        ? BorderRadius.zero
        : BorderRadius.only(
            topLeft: Radius.circular(topRadius),
            topRight: Radius.circular(topRadius),
          );

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: _h,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.bg != bg ||
        oldDelegate.topRadius != topRadius;
  }
}
