import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../rooms/room_model.dart';
import 'message_model.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Duration _timeGapForSeparator = Duration(hours: 3);

  final TextEditingController _controller = TextEditingController();

  late final DocumentReference<Map<String, dynamic>> _roomRef;
  late final CollectionReference<Map<String, dynamic>> _messagesRef;
  late final CollectionReference<Map<String, dynamic>> _membersRef;

  final Map<String, _PublicProfile> _profileCache = {};
  final Set<String> _loadingProfiles = {};

  StreamSubscription? _roomSub;

  int _membersCountLive = 0;

  @override
  void initState() {
    super.initState();

    _roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.room.id);
    _messagesRef = _roomRef.collection('messages');
    _membersRef = _roomRef.collection('members');

    // membersCount “real” desde el doc de la room (MVP)
    _roomSub = _roomRef.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final raw = data['membersCount'];
      final count = raw is int ? raw : (raw is num ? raw.toInt() : 0);

      if (mounted) {
        setState(() => _membersCountLive = count);
      }
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? _myMemberRef() {
    final user = _currentUser;
    if (user == null) return null;
    return _membersRef.doc(user.uid);
  }

  Future<_PublicProfile> _getMyProfile() async {
    final user = _currentUser;
    if (user == null) {
      return const _PublicProfile(displayName: 'Usuario', username: '');
    }

    final uid = user.uid;
    if (_profileCache.containsKey(uid)) return _profileCache[uid]!;

    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? {};

    final p = _PublicProfile(
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'Usuario',
      username: (data['username'] as String?)?.trim() ?? '',
    );

    _profileCache[uid] = p;
    return p;
  }

  Future<void> _ensureProfilesLoaded(Iterable<String> uids) async {
    final toLoad = uids
        .where((id) => id.trim().isNotEmpty)
        .where((id) => !_profileCache.containsKey(id))
        .where((id) => !_loadingProfiles.contains(id))
        .toList();

    if (toLoad.isEmpty) return;

    for (final uid in toLoad) {
      _loadingProfiles.add(uid);
      unawaited(() async {
        try {
          final snap =
              await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final data = snap.data() ?? {};
          final p = _PublicProfile(
            displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
                ? (data['displayName'] as String).trim()
                : 'Usuario',
            username: (data['username'] as String?)?.trim() ?? '',
          );
          _profileCache[uid] = p;
        } finally {
          _loadingProfiles.remove(uid);
          if (mounted) setState(() {});
        }
      }());
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = _currentUser;
    if (user == null) return;

    _controller.clear();

    await _messagesRef.add({
      'type': 'user',
      'authorId': user.uid,
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendSystem(String text) async {
    await _messagesRef.add({
      'type': 'system',
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _joinAsMember() async {
    final user = _currentUser;
    final myMemberRef = _myMemberRef();
    if (user == null || myMemberRef == null) return;

    final profile = await _getMyProfile();

    // 1) Crear member + incrementar contador (transaction)
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final memberSnap = await tx.get(myMemberRef);
      if (memberSnap.exists) return;

      tx.set(myMemberRef, {
        'uid': user.uid,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'displayNameSnapshot': profile.displayName,
      });

      tx.set(_roomRef, {
        'membersCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });

    // 2) Mensaje system (ya eres miembro, y rules lo permitirán)
    await _sendSystem('${profile.displayName} se ha unido a esta Fiesta.');
  }

  Future<void> _leaveAsMember() async {
    final user = _currentUser;
    final myMemberRef = _myMemberRef();
    if (user == null || myMemberRef == null) return;

    final profile = await _getMyProfile();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final memberSnap = await tx.get(myMemberRef);
      if (!memberSnap.exists) return;

      tx.delete(myMemberRef);

      // Evitar negativos (MVP): si no existe el campo, asumimos 0
      final roomSnap = await tx.get(_roomRef);
      final data = roomSnap.data() ?? {};
      final raw = data['membersCount'];
      final current = raw is int ? raw : (raw is num ? raw.toInt() : 0);
      final next = (current - 1) < 0 ? 0 : (current - 1);

      tx.set(_roomRef, {
        'membersCount': next,
      }, SetOptions(merge: true));
    });

    await _sendSystem('${profile.displayName} ha abandonado esta Fiesta.');
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  String _formatSeparator(DateTime dt) {
    final months = const [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sept',
      'oct',
      'nov',
      'dic',
    ];

    final m = months[dt.month - 1];
    return '${dt.day} $m ${dt.year}, ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  List<_ChatItem> _buildItemsWithSeparators(List<Message> messages) {
    final items = <_ChatItem>[];
    Message? prev;

    for (final msg in messages) {
      if (prev != null) {
        final changedDay = _isDifferentDay(prev!.createdAt, msg.createdAt);
        final gap = msg.createdAt.difference(prev!.createdAt);

        if (changedDay || gap >= _timeGapForSeparator) {
          items.add(_ChatItem.separator(_formatSeparator(msg.createdAt)));
        }
      }

      items.add(_ChatItem.message(msg));
      prev = msg;
    }

    return items;
  }

  Widget _buildRoomHeader({
    required bool isMember,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          // FILA 1: back + img sala + nombre + owner + info
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '(Owner: pendiente)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _openInfoSheet(isMember: isMember),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // FILA 2: Noticias (izq) + miembros (der)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Noticias (pendiente)')),
                    );
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.campaign_outlined, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Noticias',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _MembersMini(
                roomId: widget.room.id,
                membersCount: _membersCountLive,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // FILA 3: Roleplay selector placeholder
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 18),
                SizedBox(width: 10),
                Text(
                  'Roleplay',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Spacer(),
                Icon(Icons.expand_more),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInfoSheet({required bool isMember}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.room.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sala: ${widget.room.type == RoomType.public ? 'pública' : 'grupo'} · ID: ${widget.room.id}',
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 18),
                if (!isMember)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _joinAsMember();
                      },
                      child: const Text('Unirme a la sala'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.9),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _leaveAsMember();
                      },
                      child: const Text('Abandonar sala'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSeparator(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder({double radius = 18}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      child: Icon(Icons.person, size: radius, color: Colors.white70),
    );
  }

  Widget _buildChatBubble({
    required bool isMine,
    required String displayName,
    required String text,
    required bool showHeader,
  }) {
    final bubbleColor = Colors.white10;
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bubbleRadius = BorderRadius.circular(12); // <- ya reducido, estilo ProjectZ-ish

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: bubbleRadius,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14.5),
      ),
    );

    if (!showHeader) {
      return Column(
        crossAxisAlignment: alignment,
        children: [
          bubble,
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isMine) ...[
              _buildAvatarPlaceholder(radius: 18),
              const SizedBox(width: 10),
              Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ] else ...[
              Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              _buildAvatarPlaceholder(radius: 18),
            ],
          ],
        ),
        const SizedBox(height: 6),
        bubble,
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildComposer({required bool isMember}) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          border: const Border(
            top: BorderSide(color: Colors.white10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // fila input
            Row(
              children: [
                // Placeholder futuro selector personaje/usuario
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white12,
                  child: const Icon(Icons.person, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: isMember,
                    decoration: InputDecoration(
                      hintText: isMember
                          ? 'Escribe tu mensaje...'
                          : 'Únete a la sala para hablar...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: isMember
                        ? _sendMessage
                        : () async {
                            // si no es miembro, abrimos join rápido
                            await _joinAsMember();
                          },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // fila iconos (placeholder futuro)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _BottomIcon(Icons.multitrack_audio),
                _BottomIcon(Icons.image_outlined),
                _BottomIcon(Icons.emoji_emotions_outlined),
                _BottomIcon(Icons.auto_awesome_outlined),
                _BottomIcon(Icons.casino_outlined),
                _BottomIcon(Icons.add),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No autenticado')),
      );
    }

    final myMemberRef = _myMemberRef()!;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: myMemberRef.snapshots(),
          builder: (context, memberSnap) {
            final isMember = memberSnap.data?.exists == true;

            return Column(
              children: [
                _buildRoomHeader(isMember: isMember),
                const Divider(height: 1, color: Colors.white10),

                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _messagesRef
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(child: Text('Error cargando mensajes'));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No hay mensajes'));
                      }

                      final messages = docs.map((d) => Message.fromFirestore(d)).toList();

                      // Prefetch perfiles (solo mensajes user con authorId)
                      final authorIds = messages
                          .where((m) => m.type == MessageType.user)
                          .map((m) => m.authorId ?? '')
                          .where((id) => id.isNotEmpty)
                          .toSet();

                      _ensureProfilesLoaded(authorIds);

                      final items = _buildItemsWithSeparators(messages);

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];

                          if (item.kind == _ChatItemKind.separator) {
                            return _buildTimeSeparator(item.separatorText!);
                          }

                          final msg = item.message!;
                          if (msg.type == MessageType.system) {
                            return _buildSystemMessage(msg.content);
                          }

                          final authorId = msg.authorId ?? '';
                          final isMine = authorId == user.uid;

                          final profile = _profileCache[authorId];
                          final displayName = profile?.displayName ?? 'Usuario';

                          // Para agrupar por usuario: header solo si cambia de autor o venimos de system/separator
                          bool showHeader = true;
                          if (index > 0) {
                            final prev = items[index - 1];
                            if (prev.kind == _ChatItemKind.message) {
                              final prevMsg = prev.message!;
                              if (prevMsg.type == MessageType.user &&
                                  prevMsg.authorId == authorId) {
                                showHeader = false;
                              }
                            }
                          }

                          return _buildChatBubble(
                            isMine: isMine,
                            displayName: displayName,
                            text: msg.content,
                            showHeader: showHeader,
                          );
                        },
                      );
                    },
                  ),
                ),

                _buildComposer(isMember: isMember),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomIcon extends StatelessWidget {
  final IconData icon;
  const _BottomIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Colors.white70, size: 22);
  }
}

class _MembersMini extends StatelessWidget {
  final String roomId;
  final int membersCount;

  const _MembersMini({
    required this.roomId,
    required this.membersCount,
  });

  @override
  Widget build(BuildContext context) {
    final membersRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('members');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: membersRef.orderBy('joinedAt', descending: true).limit(4).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final avatarsToShow = docs.length.clamp(0, 4);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18.0 * (avatarsToShow == 0 ? 1 : avatarsToShow) + 10,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(avatarsToShow, (i) {
                  return Positioned(
                    left: i * 18.0,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white12,
                      child: const Icon(Icons.person, size: 14, color: Colors.white70),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$membersCount',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        );
      },
    );
  }
}

class _PublicProfile {
  final String displayName;
  final String username;
  const _PublicProfile({required this.displayName, required this.username});
}

enum _ChatItemKind { message, separator }

class _ChatItem {
  final _ChatItemKind kind;
  final Message? message;
  final String? separatorText;

  const _ChatItem._(this.kind, {this.message, this.separatorText});

  factory _ChatItem.message(Message msg) => _ChatItem._(_ChatItemKind.message, message: msg);

  factory _ChatItem.separator(String text) =>
      _ChatItem._(_ChatItemKind.separator, separatorText: text);
}
