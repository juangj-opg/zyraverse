import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import 'discover_screen.dart';
import '../profile/profile_screen.dart';
import '../rooms/create_room_screen.dart';
import '../rooms/room_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _roomsService = RoomsService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      try {
        await _roomsService.ensureDefaultRooms(seededByUid: uid);
      } catch (_) {
        // No bloqueamos UI si reglas / red / etc.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HomeHeader(uid: uid),
            const Expanded(child: DiscoverScreen()),
          ],
        ),
      ),
      bottomNavigationBar: _HomeBottomBar(
        onCreateTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
          );
        },
        onChatsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoomListScreen()),
          );
        },
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String? uid;

  const _HomeHeader({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const SizedBox(height: 68);
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final displayName = (data['displayName'] as String?)?.trim();
          final username = (data['username'] as String?)?.trim();

          final title = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : ((username != null && username.isNotEmpty) ? username : 'Usuario');

          return Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(profileUid: uid!),
                    ),
                  );
                },
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Roleando',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Búsqueda: pendiente')),
                  );
                },
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificaciones: pendiente')),
                  );
                },
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onChatsTap;

  const _HomeBottomBar({
    required this.onCreateTap,
    required this.onChatsTap,
  });

  static const double _visualHeight = 78;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: _visualHeight,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Colors.white10, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _BottomItem(
                icon: Icons.explore_outlined,
                label: 'Descubre',
                selected: true,
                onTap: () {
                  // Estamos en Home/Discover.
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 50,
              height: 50,
              child: Material(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onCreateTap,
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BottomItem(
                icon: Icons.chat_bubble_outline,
                label: 'Chats',
                selected: false,
                onTap: onChatsTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white60;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
