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

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final data = snap.data();
    if (!mounted) return;

    setState(() {
      _myDisplayName = (data?['displayName'] as String?)?.trim();
    });
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

    // 1) Crear el mensaje
    // 2) Actualizar "último mensaje" de la sala (para el listado)
    final batch = FirebaseFirestore.instance.batch();

    final msgRef = _messagesRef.doc();
    batch.set(msgRef, {
      'type': 'text',
      'authorId': user.uid,
      'authorDisplayName': safeName,
      'content': text,
      'createdAt': now,
    });

    batch.set(_roomRef, {
      'lastMessageText': text,
      'lastMessageAt': now,
      'lastActivityAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _roomsService.joinRoom(roomId: widget.room.id, uid: user.uid);

    // Mensaje de sistema opcional (no depende de ser miembro por reglas)
    final name = (_myDisplayName ?? '').trim();
    final safeName = name.isNotEmpty ? name : 'Usuario';

    await _messagesRef.add({
      'type': 'system',
      'authorId': null,
      'authorDisplayName': null,
      'content': '$safeName se ha unido a esta sala.',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // También actualizamos última actividad
    await _roomRef.set(
      {'lastActivityAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  String _formatRelative(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';

    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm';
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

    // separador si cambia el día o si hay gap >= 3h
    final dayChanged = current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;

    return dayChanged || diff.inHours >= 3;
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
        final memberCount = (roomData['memberCount'] is int)
            ? roomData['memberCount'] as int
            : 24; // fallback placeholder si no existe

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
                          // Fila 1: back + img sala + nombre + owner + info
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
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ownerText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white60,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  // placeholder info
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

                          // Fila 2: Noticias (izq) + miembros (dcha, sin borde)
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

                              // Bloque miembros estilo ProjectZ (avatars pisados + número)
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

                          // Fila 3: selector Roleplay (placeholder)
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
                        stream: _messagesRef
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
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

                          final messages =
                              docs.map((d) => Message.fromFirestore(d)).toList();

                          // Construimos una lista “mixta” con separadores
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

                            final sameAsPrev =
                                prevMsg != null && prevMsg.type == 'text' && m.type == 'text' &&
                                prevMsg.authorId == m.authorId;

                            final sameAsNext =
                                nextMsg != null && nextMsg.type == 'text' && m.type == 'text' &&
                                nextMsg.authorId == m.authorId;

                            final isFirstOfGroup = !sameAsPrev;
                            final isLastOfGroup = !sameAsNext;

                            items.add(
                              _ChatItem.message(
                                m,
                                isFirstOfGroup: isFirstOfGroup,
                                isLastOfGroup: isLastOfGroup,
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.separatorText!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        msg.content,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final isMe = uid != null && msg.authorId == uid;
                              final name = (msg.authorDisplayName ?? 'Usuario').trim();

                              return _MessageGroupBubble(
                                isMe: isMe,
                                displayName: name.isNotEmpty ? name : 'Usuario',
                                text: msg.content,
                                showHeader: item.isFirstOfGroup!,
                                showAvatar: item.isFirstOfGroup!,
                                addBottomGap: item.isLastOfGroup!,
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // ESPECTADOR: barra de unión + input bloqueado
                    SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          if (!isMember)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_outline, size: 18, color: Colors.white70),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Eres espectador. Únete para poder escribir.',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _joinRoom,
                                      child: const Text('Unirse'),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          _ChatInputBar(
                            controller: _controller,
                            enabled: isMember,
                            onSend: () => _sendMessage(isMember: isMember),
                          ),
                        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        children: [
          // fila de iconos (reservada)
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
                  color: enabled ? Colors.white10 : Colors.white12,
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
      ),
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

class _MessageGroupBubble extends StatelessWidget {
  final bool isMe;
  final String displayName;
  final String text;

  final bool showHeader;
  final bool showAvatar;
  final bool addBottomGap;

  const _MessageGroupBubble({
    required this.isMe,
    required this.displayName,
    required this.text,
    required this.showHeader,
    required this.showAvatar,
    required this.addBottomGap,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.white10;

    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final rowAlign = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: EdgeInsets.only(bottom: addBottomGap ? 14 : 6),
      child: Row(
        mainAxisAlignment: rowAlign,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && showAvatar) ...[
            const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.person, color: Colors.white70),
            ),
            const SizedBox(width: 10),
          ] else if (!isMe) ...[
            const SizedBox(width: 40),
            const SizedBox(width: 10),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: align,
              children: [
                if (showHeader)
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(14), // “menos redondo”
                  ),
                  child: Text(text),
                ),
              ],
            ),
          ),

          if (isMe && showAvatar) ...[
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
