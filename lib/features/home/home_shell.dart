import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import '../rooms/room_list_screen.dart';
import 'discover_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _roomsService = RoomsService();

  @override
  void initState() {
    super.initState();

    // Seed de salas por defecto (prototipo). Si ya existen, no hace nada.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      try {
        await _roomsService.ensureDefaultRooms(seededByUid: uid);
      } catch (_) {
        // Si reglas no lo permiten o no hay conexión, no bloqueamos la UI.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final tabs = <Widget>[
      const DiscoverScreen(),
      const RoomListScreen(embedded: true),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HomeHeader(uid: uid),
            Expanded(child: tabs[_index]),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
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
                  // Perfil (placeholder: sin edición todavía)
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
                  // placeholder búsqueda
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Búsqueda: pendiente')),
                  );
                },
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: () {
                  // placeholder notificaciones
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

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomBar({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: onChanged,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white60,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.explore_outlined),
          activeIcon: Icon(Icons.explore),
          label: 'Descubre',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chats',
        ),
      ],
    );
  }
}
