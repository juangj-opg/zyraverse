import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/message_service.dart';
import '../../core/services/rooms_service.dart';
import '../rooms/room_model.dart';
import 'message_model.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatItem {
  final MessageModel? message;
  final String? separatorText;

  const _ChatItem._({this.message, this.separatorText});

  bool get isSeparator => separatorText != null;

  factory _ChatItem.message(MessageModel m) => _ChatItem._(message: m);
  factory _ChatItem.separator(String text) => _ChatItem._(separatorText: text);
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final RoomsService _roomsService = RoomsService();
  final MessageService _messageService = MessageService();

  String _myDisplayName = 'Usuario';
  bool _loadingProfile = true;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final data = doc.data() ?? {};
      final dn = (data['displayName'] ?? '').toString().trim();
      if (dn.isNotEmpty) _myDisplayName = dn;
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // "29 sept 2021, 14:43"
  String _formatGapSeparator(DateTime dt) {
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sept','oct','nov','dic'];
    final d = dt.day.toString().padLeft(2, '0');
    final m = months[(dt.month - 1).clamp(0, 11)];
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d $m $y, $hh:$mm';
  }

  Future<void> _joinRoom() async {
    await _roomsService.joinRoom(roomId: widget.roomId, displayName: _myDisplayName);
    await _messageService.sendSystemMessage(
      roomId: widget.roomId,
      text: '$_myDisplayName se ha unido a esta sala.',
    );
  }

  Future<void> _leaveRoom() async {
    await _roomsService.leaveRoom(roomId: widget.roomId);
    await _messageService.sendSystemMessage(
      roomId: widget.roomId,
      text: '$_myDisplayName ha abandonado esta sala.',
    );
  }

  Future<void> _sendMessage(bool isMember) async {
    if (!isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes unirte a la sala para poder escribir.')),
      );
      return;
    }

    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();
    await _messageService.sendUserMessage(
      roomId: widget.roomId,
      text: text,
      authorDisplayName: _myDisplayName,
    );
    _scrollToBottomSoon();
  }

  void _openInfoSheet({required bool isMember}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70),
                    SizedBox(width: 10),
                    Text(
                      'Información de la sala',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Placeholder: aquí irá la información completa, miembros, reglas, etc.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                if (isMember)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _leaveRoom();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  // Preview de miembros tipo ProjectZ: iconos pisados y número (sin “marco” alrededor)
  Widget _membersPreviewCount(int countIcons) {
    final n = countIcons.clamp(0, 3);
    return SizedBox(
      width: 70,
      height: 24,
      child: Stack(
        children: List.generate(n, (i) {
          final left = (i * 14).toDouble();
          return Positioned(
            left: left,
            top: 0,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: const Color(0xFF1C1C26),
              child: Icon(Icons.person, size: 14, color: Colors.white.withOpacity(0.85)),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B0F),
        body: Center(child: Text('No autenticado', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: SafeArea(
        child: StreamBuilder<RoomModel?>(
          stream: _roomsService.watchRoom(widget.roomId),
          builder: (context, roomSnap) {
            final room = roomSnap.data;

            final roomName = room?.name ?? 'Sala';
            final ownerLine = '(Owner: pendiente)';

            return StreamBuilder<bool>(
              stream: _roomsService.watchIsMember(widget.roomId),
              builder: (context, memberSnap) {
                final isMember = memberSnap.data ?? false;

                return Column(
                  children: [
                    // ---------------- HEADER (3 filas) ----------------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        children: [
                          // Fila 1
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFF1C1C26),
                                child: Icon(Icons.image_outlined, color: Colors.white70),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roomName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ownerLine,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _openInfoSheet(isMember: isMember),
                                icon: const Icon(Icons.info_outline, color: Colors.white),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Fila 2: Noticias izq + Miembros dcha
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF12121A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Noticias: pendiente')),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.campaign_outlined, color: Colors.white70),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Noticias',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right, color: Colors.white54),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Miembros: iconos pisados + contador (sin marco alrededor)
                              StreamBuilder<int>(
                                stream: _roomsService.watchMembersPreviewCount(widget.roomId, limit: 3),
                                builder: (context, prevSnap) {
                                  final iconsCount = prevSnap.data ?? 0;
                                  final membersCount = room?.membersCount ?? 0;

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _membersPreviewCount(iconsCount),
                                      Text(
                                        '$membersCount',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Fila 3: Roleplay selector (placeholder)
                          Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF12121A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_outlined, color: Colors.white70),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Roleplay',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFF1A1A22)),

                    // ---------------- MENSAJES ----------------
                    Expanded(
                      child: StreamBuilder<List<MessageModel>>(
                        stream: _messageService.watchMessages(widget.roomId),
                        builder: (context, msgSnap) {
                          if (msgSnap.hasError) {
                            return Center(
                              child: Text('Error: ${msgSnap.error}', style: const TextStyle(color: Colors.white70)),
                            );
                          }
                          if (!msgSnap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final msgs = msgSnap.data!;
                          final items = <_ChatItem>[];

                          DateTime? prev;
                          for (final m in msgs) {
                            if (prev != null) {
                              final gapMin = m.createdAt.difference(prev!).inMinutes;
                              if (gapMin >= 180) {
                                items.add(_ChatItem.separator(_formatGapSeparator(m.createdAt)));
                              }
                            }
                            items.add(_ChatItem.message(m));
                            prev = m.createdAt;
                          }

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollCtrl.hasClients) {
                              _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                            }
                          });

                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];

                              if (item.isSeparator) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        item.separatorText!,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final m = item.message!;
                              if (m.isSystem) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        m.text,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final isMe = m.authorId == _uid;
                              final displayName = (m.authorDisplayName?.trim().isNotEmpty ?? false)
                                  ? m.authorDisplayName!.trim()
                                  : 'Usuario';

                              // Agrupación: si el anterior es del mismo autor, no repetimos header
                              bool showHeader = true;
                              if (i > 0) {
                                final prevItem = items[i - 1];
                                if (!prevItem.isSeparator &&
                                    prevItem.message != null &&
                                    !prevItem.message!.isSystem &&
                                    prevItem.message!.authorId == m.authorId) {
                                  showHeader = false;
                                }
                              }

                              final bubble = Container(
                                constraints: const BoxConstraints(maxWidth: 280),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1C26),
                                  borderRadius: BorderRadius.circular(10), // más parecido a ProjectZ
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  m.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              );

                              final avatar = CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF1C1C26),
                                child: Icon(Icons.person, color: Colors.white.withOpacity(0.85)),
                              );

                              if (isMe) {
                                return Padding(
                                  padding: EdgeInsets.only(top: showHeader ? 10 : 4, bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (showHeader)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 6, bottom: 4),
                                                child: Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            bubble,
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (showHeader) avatar else const SizedBox(width: 32),
                                    ],
                                  ),
                                );
                              } else {
                                return Padding(
                                  padding: EdgeInsets.only(top: showHeader ? 10 : 4, bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (showHeader) avatar else const SizedBox(width: 32),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (showHeader)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 6, bottom: 4),
                                                child: Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            bubble,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),

                    // ---------------- BARRA “UNIRSE” si no es miembro ----------------
                    if (!isMember)
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12121A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, color: Colors.white70),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Eres espectador. Únete para poder escribir.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _loadingProfile ? null : () async => _joinRoom(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A3A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Unirse'),
                            ),
                          ],
                        ),
                      ),

                    // ---------------- INPUT + ICONOS (placeholder futuro) ----------------
                    Container(
                      color: const Color(0xFF0B0B0F),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF1C1C26),
                                child: Icon(Icons.person, color: Colors.white.withOpacity(0.85)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF12121A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: TextField(
                                    controller: _textCtrl,
                                    enabled: isMember,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Escribe tu mensaje...',
                                      hintStyle: const TextStyle(color: Colors.white38),
                                      border: InputBorder.none,
                                      suffixIcon: Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1C1C26),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.white10),
                                              ),
                                              child: const Text('A+', style: TextStyle(color: Colors.white70)),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed: () => _sendMessage(isMember),
                                              icon: const Icon(Icons.send, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (_) => _sendMessage(isMember),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Fila de iconos reservada (placeholder futuro)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              Icon(Icons.graphic_eq, color: Colors.white54),
                              Icon(Icons.image_outlined, color: Colors.white54),
                              Icon(Icons.emoji_emotions_outlined, color: Colors.white54),
                              Icon(Icons.auto_awesome_outlined, color: Colors.white54),
                              Icon(Icons.casino_outlined, color: Colors.white54),
                              Icon(Icons.add, color: Colors.white54),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
