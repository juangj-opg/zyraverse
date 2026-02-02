import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import '../rooms/room_model.dart';
import 'message_model.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _roomsService = RoomsService();
  final TextEditingController _controller = TextEditingController();

  late final DocumentReference<Map<String, dynamic>> _roomRef;
  late final CollectionReference<Map<String, dynamic>> _messagesRef;

  String? _myDisplayName;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.room.id);
    _messagesRef = _roomRef.collection('messages');
    _loadMyProfileSnapshot();
  }

  Future<void> _loadMyProfileSnapshot() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    if (!mounted) return;

    setState(() {
      _myDisplayName = (data?['displayName'] as String?)?.trim();
    });
  }

  Future<void> _safeUpdateRoomActivity({
    String? lastMessageText,
    required FieldValue now,
  }) async {
    // “Best effort”: si reglas no permiten tocar rooms/{id}, NO rompemos el envío.
    try {
      final patch = <String, dynamic>{'lastActivityAt': now};
      if (lastMessageText != null) {
        patch['lastMessageText'] = lastMessageText;
        patch['lastMessageAt'] = now;
      }
      await _roomRef.set(patch, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }
  }

  Future<void> _sendMessage({required bool isMember}) async {
    if (!isMember) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final displayName = (_myDisplayName ?? '').trim();
    final safeName = displayName.isNotEmpty ? displayName : 'Usuario';

    _controller.clear();

    final now = FieldValue.serverTimestamp();

    // 1) Guardamos SIEMPRE el mensaje con el ESQUEMA CORRECTO
    await _messagesRef.add({
      'type': 'user',
      'authorId': user.uid,
      'authorDisplayName': safeName,
      'text': text,
      'createdAt': now,
    });

    // 2) Actualizamos resumen sala (opcional)
    await _safeUpdateRoomActivity(lastMessageText: text, now: now);
  }

  Future<void> _joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _roomsService.joinRoom(roomId: widget.room.id, uid: user.uid);

    final name = (_myDisplayName ?? '').trim();
    final safeName = name.isNotEmpty ? name : 'Usuario';

    // Mensaje system con ESQUEMA CORRECTO
    await _messagesRef.add({
      'type': 'system',
      'authorId': '',
      'authorDisplayName': '',
      'text': '$safeName se ha unido a esta sala.',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _safeUpdateRoomActivity(lastMessageText: null, now: FieldValue.serverTimestamp());
  }

  String _formatDateSeparator(DateTime dt) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sept', 'oct', 'nov', 'dic'
    ];

    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hh:$mi';
  }

  bool _needsSeparator(DateTime current, DateTime? previous) {
    if (previous == null) return true;

    final diff = current.difference(previous);
    final dayChanged = current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;

    return dayChanged || diff.inHours >= 3;
  }

  String _groupKey(Message msg) {
    final aId = msg.authorId.trim();
    if (aId.isNotEmpty) return aId;
    final aName = msg.authorDisplayName.trim();
    if (aName.isNotEmpty) return aName;
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _roomRef.snapshots(),
      builder: (context, roomSnap) {
        final roomData = roomSnap.data?.data() ?? {};
        final roomName = (roomData['name'] as String?) ?? widget.room.name;
        final ownerText = '(Owner: pendiente)';
        final memberCount = (roomData['memberCount'] is int) ? roomData['memberCount'] as int : 24;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (uid == null)
              ? const Stream.empty()
              : _roomsService.watchMyMembership(roomId: widget.room.id, uid: uid),
          builder: (context, memberSnap) {
            final isMember = memberSnap.data?.exists == true;

            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    // HEADER 3 FILAS
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        children: [
                          // Fila 1
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.image_outlined, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roomName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ownerText,
                                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Info'),
                                      content: const Text('Pendiente de implementar.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.info_outline),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Fila 2
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.campaign_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Noticias',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 44,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      height: 44,
                                      child: Stack(
                                        alignment: Alignment.centerRight,
                                        children: [
                                          _memberAvatar(left: 0),
                                          _memberAvatar(left: 14),
                                          _memberAvatar(left: 28),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$memberCount',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Fila 3
                          Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.shield_outlined, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Roleplay',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // MENSAJES
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _messagesRef.orderBy('createdAt', descending: false).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error cargando mensajes: ${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(child: Text('No hay mensajes'));
                          }

                          final messages = docs.map((d) => Message.fromDoc(d)).toList();

                          final items = <_ChatItem>[];
                          DateTime? prevTime;

                          for (int i = 0; i < messages.length; i++) {
                            final m = messages[i];

                            final needsSep = _needsSeparator(m.createdAt, prevTime);
                            if (needsSep) {
                              items.add(_ChatItem.separator(_formatDateSeparator(m.createdAt)));
                            }

                            final prevMsg = (i > 0) ? messages[i - 1] : null;
                            final nextMsg = (i < messages.length - 1) ? messages[i + 1] : null;

                            final mKey = _groupKey(m);
                            final prevKey = prevMsg == null ? '' : _groupKey(prevMsg);
                            final nextKey = nextMsg == null ? '' : _groupKey(nextMsg);

                            // Agrupamos SOLO mensajes de usuario
                            final sameAsPrev =
                                prevMsg != null &&
                                prevMsg.type == 'user' &&
                                m.type == 'user' &&
                                mKey == prevKey;

                            final sameAsNext =
                                nextMsg != null &&
                                nextMsg.type == 'user' &&
                                m.type == 'user' &&
                                mKey == nextKey;

                            items.add(
                              _ChatItem.message(
                                m,
                                isFirstOfGroup: !sameAsPrev,
                                isLastOfGroup: !sameAsNext,
                              ),
                            );

                            prevTime = m.createdAt;
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];

                              if (item.kind == _ChatItemKind.separator) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.separatorText!,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final msg = item.message!;
                              if (msg.type == 'system') {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        msg.text,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final isMe = uid != null && msg.authorId == uid;
                              final name = msg.authorDisplayName.trim().isNotEmpty
                                  ? msg.authorDisplayName.trim()
                                  : 'Usuario';

                              return _BlockBubble(
                                isMe: isMe,
                                displayName: name,
                                text: msg.text,
                                showHeaderAndAvatar: item.isFirstOfGroup!,
                                addBottomGap: item.isLastOfGroup!,
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // BARRA INFERIOR
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: isMember
                            ? _ChatInputBar(
                                controller: _controller,
                                enabled: true,
                                onSend: () => _sendMessage(isMember: true),
                              )
                            : _JoinChatBar(onJoin: _joinRoom),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _memberAvatar({required double left}) {
    return Positioned(
      left: left,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black87,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: const CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(Icons.person, size: 16, color: Colors.white70),
        ),
      ),
    );
  }
}

class _JoinChatBar extends StatelessWidget {
  final VoidCallback onJoin;

  const _JoinChatBar({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onJoin,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Unirse al chat',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Iconos ARRIBA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _ActionIcon(Icons.graphic_eq),
            _ActionIcon(Icons.image_outlined),
            _ActionIcon(Icons.emoji_emotions_outlined),
            _ActionIcon(Icons.auto_awesome_outlined),
            _ActionIcon(Icons.casino_outlined),
            _ActionIcon(Icons.add),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.person, color: Colors.white70),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu mensaje...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 44,
              width: 46,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: enabled ? onSend : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  const _ActionIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 34,
      child: Center(
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }
}

/// Bloque estilo ProjectZ (como tu 2ª imagen):
/// - Nombre (Usuario/Kyrox) SOLO al inicio del grupo
/// - Avatar SOLO al inicio del grupo
/// - Burbujas compactas, poco redondeo
class _BlockBubble extends StatelessWidget {
  final bool isMe;
  final String displayName;
  final String text;

  final bool showHeaderAndAvatar;
  final bool addBottomGap;

  const _BlockBubble({
    required this.isMe,
    required this.displayName,
    required this.text,
    required this.showHeaderAndAvatar,
    required this.addBottomGap,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.white10;
    final rowAlign = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    final radius = BorderRadius.circular(12);

    return Padding(
      padding: EdgeInsets.only(bottom: addBottomGap ? 14 : 6),
      child: Row(
        mainAxisAlignment: rowAlign,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IZQ: avatar o hueco
          if (!isMe && showHeaderAndAvatar) ...[
            const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.person, color: Colors.white70),
            ),
            const SizedBox(width: 10),
          ] else if (!isMe) ...[
            const SizedBox(width: 40),
            const SizedBox(width: 10),
          ],

          // Columna (nombre + burbuja)
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showHeaderAndAvatar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: radius,
                    ),
                    child: Text(text),
                  ),
                ),
              ],
            ),
          ),

          // DCHA: avatar o hueco
          if (isMe && showHeaderAndAvatar) ...[
            const SizedBox(width: 10),
            const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.person, color: Colors.white70),
            ),
          ] else if (isMe) ...[
            const SizedBox(width: 10),
            const SizedBox(width: 40),
          ],
        ],
      ),
    );
  }
}

enum _ChatItemKind { separator, message }

class _ChatItem {
  final _ChatItemKind kind;
  final String? separatorText;

  final Message? message;
  final bool? isFirstOfGroup;
  final bool? isLastOfGroup;

  _ChatItem.separator(this.separatorText)
      : kind = _ChatItemKind.separator,
        message = null,
        isFirstOfGroup = null,
        isLastOfGroup = null;

  _ChatItem.message(
    this.message, {
    required this.isFirstOfGroup,
    required this.isLastOfGroup,
  })  : kind = _ChatItemKind.message,
        separatorText = null;
}
