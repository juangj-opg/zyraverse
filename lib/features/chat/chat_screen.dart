import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/public_profile.dart';
import '../rooms/room_model.dart';
import 'message_model.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final DocumentReference<Map<String, dynamic>> _roomRef;
  late final CollectionReference<Map<String, dynamic>> _messagesRef;

  final Map<String, PublicProfile?> _profileCache = {};
  final Map<String, Future<PublicProfile?>> _profileFutureCache = {};

  int _lastMessageCount = 0;
  bool _myProfileEnsured = false;

  // --- UI tuning (ProjectZ-ish) ---
  static const double _avatarSize = 36;
  static const double _avatarGap = 10;

  // Más “cuadrado” como ProjectZ
  static const double _bubbleRadius = 8;

  // Footer sizes (reservados para futuro)
  static const double _footerInputHeight = 46;
  static const double _footerIconRowHeight = 44;

  // Placeholder members
  static const int _membersCountPlaceholder = 24;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.room.id);
    _messagesRef = _roomRef.collection('messages');
    _ensureMyPublicProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Garantiza que el perfil público exista y NO tenga photoURL (avatar placeholder)
  Future<void> _ensureMyPublicProfile() async {
    if (_myProfileEnsured) return;
    _myProfileEnsured = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    try {
      final userSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userSnap.data();
      if (data == null) return;

      final username = (data['username'] as String?)?.trim() ?? '';
      final displayName = (data['displayName'] as String?)?.trim() ?? '';

      if (username.isEmpty || displayName.isEmpty) return;

      await FirebaseFirestore.instance.collection('profiles').doc(uid).set(
        {
          'username': username,
          'displayName': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
          // Por decisión tuya: NO usar foto de Google por defecto
          'photoURL': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );

      _profileCache[uid] = PublicProfile(
        uid: uid,
        username: username,
        displayName: displayName,
        photoURL: null,
      );
    } catch (_) {
      // silencioso
    }
  }

  Future<PublicProfile?> _loadProfile(String uid) {
    if (_profileCache.containsKey(uid)) {
      return Future.value(_profileCache[uid]);
    }

    return _profileFutureCache.putIfAbsent(uid, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(uid)
            .get();

        if (!doc.exists) {
          _profileCache[uid] = null;
          return null;
        }

        final p = PublicProfile.fromDoc(doc);
        _profileCache[uid] = p;
        return p;
      } catch (_) {
        _profileCache[uid] = null;
        return null;
      }
    });
  }

  void _autoScrollIfNeeded(int newCount) {
    if (newCount <= _lastMessageCount) return;
    _lastMessageCount = newCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _controller.clear();

    final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;

    final batch = FirebaseFirestore.instance.batch();
    final messageDoc = _messagesRef.doc();

    batch.set(messageDoc, {
      'authorId': user.uid,
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _roomRef,
      {
        'lastMessagePreview': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'sortAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // -----------------------
  // UI helpers
  // -----------------------

  Widget _avatarPlaceholder({bool visible = true}) {
    if (!visible) {
      return const SizedBox(width: _avatarSize, height: _avatarSize);
    }

    return CircleAvatar(
      radius: _avatarSize / 2,
      backgroundColor: Colors.white.withOpacity(0.08),
      child: Icon(
        Icons.person,
        size: 18,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }

  // Avatar pequeño para “miembros” (SIN contenedor/borde alrededor del bloque)
  Widget _memberAvatarCircle({double size = 22}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
        // Esto NO es un borde del bloque de miembros; es solo para separar círculos al solaparse
        border: Border.all(
          color: Colors.black.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.60,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }

  // Miembros al estilo ProjectZ: avatares pisándose + contador, SIN “chip” alrededor
  Widget _membersInline() {
    const double size = 22;
    const double overlap = 8; // cuanto más alto, más se pisan
    const int shown = 3; // 3-4 según quieras (en ProjectZ suelen verse 3)

    final double step = size - overlap;
    final double stackWidth = size + (shown - 1) * step;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(shown, (i) {
              return Positioned(
                left: i * step,
                child: _memberAvatarCircle(size: size),
              );
            }),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$_membersCountPlaceholder',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }

  // Placeholder “imagen de sala”
  Widget _roomImagePlaceholder() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Icon(Icons.image_outlined,
          size: 18, color: Colors.white.withOpacity(0.85)),
    );
  }

  // Selector de personaje/usuario (placeholder por ahora)
  Widget _characterSlotButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selector de personaje (próximamente)')),
        );
      },
      child: Container(
        width: _footerInputHeight,
        height: _footerInputHeight,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Center(
          child: Icon(
            Icons.person,
            size: 20,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }

  Widget _aPlusButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opciones de texto (A+) (próximamente)')),
        );
      },
      child: Container(
        width: 42,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Center(
          child: Text(
            'A+',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBarButton(IconData icon, String label) {
    return IconButton(
      tooltip: label,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label (próximamente)')),
        );
      },
      icon: Icon(icon, color: Colors.white.withOpacity(0.85)),
    );
  }

  BoxDecoration _chipDecoration() {
    return BoxDecoration(
      color: Colors.black.withOpacity(0.14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    );
  }

  // ===========================
  // CABECERA: 3 FILAS (ProjectZ)
  // ===========================
  Widget _projectZHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          // FILA 1: Back + Img sala + Nombre (owner debajo) + Info
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back,
                      color: Colors.white.withOpacity(0.90)),
                ),
              ),
              const SizedBox(width: 6),
              _roomImagePlaceholder(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(Owner: pendiente)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Info sala (próximamente)')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // FILA 2: DOS APARTADOS (Noticias) + (Miembros)
          // -> Miembros SIN chip, y con avatares solapados (ProjectZ)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Noticias (próximamente)')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: _chipDecoration(),
                    child: Row(
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 18, color: Colors.white.withOpacity(0.88)),
                        const SizedBox(width: 10),
                        Text(
                          'Noticias',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withOpacity(0.90),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            color: Colors.white.withOpacity(0.65)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Miembros: SIN contenedor/borde exterior
              _membersInline(),
            ],
          ),

          const SizedBox(height: 10),

          // FILA 3: Roleplay selector (abrirá selector de personajes)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selector Roleplay (próximamente)')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: _chipDecoration(),
              child: Row(
                children: [
                  Icon(Icons.shield,
                      size: 18, color: Colors.white.withOpacity(0.88)),
                  const SizedBox(width: 10),
                  Text(
                    'Roleplay',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo “fullscreen”
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1B1B1F),
                  Color(0xFF111114),
                ],
              ),
            ),
          ),

          // Overlay oscuro
          Container(color: Colors.black.withOpacity(0.18)),

          SafeArea(
            child: Column(
              children: [
                _projectZHeader(),

                // Chat
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
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No hay mensajes'));
                      }

                      final messages = snapshot.data!.docs
                          .map((doc) => Message.fromFirestore(doc))
                          .toList();

                      _autoScrollIfNeeded(messages.length);

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];

                          final prevAuthorId =
                              index > 0 ? messages[index - 1].authorId : null;

                          final isFirstInGroup = prevAuthorId != msg.authorId;
                          final topPadding = isFirstInGroup ? 14.0 : 6.0;

                          final isMine =
                              (myUid != null && msg.authorId == myUid);

                          return Padding(
                            padding: EdgeInsets.only(top: topPadding),
                            child: FutureBuilder<PublicProfile?>(
                              future: _loadProfile(msg.authorId),
                              builder: (context, profSnap) {
                                final profile = profSnap.data;

                                final displayName =
                                    (profile?.displayName.isNotEmpty == true)
                                        ? profile!.displayName
                                        : 'Usuario';

                                return _ProjectZMessageRow(
                                  isMine: isMine,
                                  avatar: _avatarPlaceholder(
                                      visible: isFirstInGroup),
                                  reserveAvatarSpace: !isFirstInGroup,
                                  avatarSize: _avatarSize,
                                  avatarGap: _avatarGap,
                                  showHeader: isFirstInGroup,
                                  displayName: displayName,
                                  content: msg.content,
                                  bubbleRadius: _bubbleRadius,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Footer estilo ProjectZ (reservado)
                _ProjectZFooter(
                  controller: _controller,
                  inputHeight: _footerInputHeight,
                  iconRowHeight: _footerIconRowHeight,
                  characterSlot: _characterSlotButton(),
                  aPlus: _aPlusButton(),
                  onSend: _sendMessage,
                  iconButtons: [
                    _iconBarButton(Icons.graphic_eq, 'Voz'),
                    _iconBarButton(Icons.image, 'Imagen'),
                    _iconBarButton(Icons.emoji_emotions, 'Emoji'),
                    _iconBarButton(Icons.auto_awesome, 'Acción'),
                    _iconBarButton(Icons.casino, 'Dados'),
                    _iconBarButton(Icons.add, 'Más'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectZMessageRow extends StatelessWidget {
  final bool isMine;

  final Widget avatar;
  final bool reserveAvatarSpace;
  final double avatarSize;
  final double avatarGap;

  final bool showHeader;
  final String displayName;
  final String content;

  final double bubbleRadius;

  const _ProjectZMessageRow({
    required this.isMine,
    required this.avatar,
    required this.reserveAvatarSpace,
    required this.avatarSize,
    required this.avatarGap,
    required this.showHeader,
    required this.displayName,
    required this.content,
    required this.bubbleRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.white.withOpacity(0.08);

    final avatarSlot = reserveAvatarSpace
        ? SizedBox(width: avatarSize, height: avatarSize)
        : avatar;

    final bubbleDecoration = BoxDecoration(
      color: bubbleColor,
      borderRadius: BorderRadius.circular(bubbleRadius),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    );

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;

    if (!isMine) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarSlot,
          SizedBox(width: avatarGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: bubbleDecoration,
                    child: Text(
                      content,
                      style: const TextStyle(fontSize: 15, height: 1.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: bubbleDecoration,
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 15, height: 1.25),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: avatarGap),
        avatarSlot,
      ],
    );
  }
}

class _ProjectZFooter extends StatelessWidget {
  final TextEditingController controller;
  final double inputHeight;
  final double iconRowHeight;

  final Widget characterSlot;
  final Widget aPlus;
  final VoidCallback onSend;
  final List<Widget> iconButtons;

  const _ProjectZFooter({
    required this.controller,
    required this.inputHeight,
    required this.iconRowHeight,
    required this.characterSlot,
    required this.aPlus,
    required this.onSend,
    required this.iconButtons,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                characterSlot,
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: inputHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Escribe tu mensaje...',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => onSend(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        aPlus,
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onSend,
                          child: Container(
                            width: 44,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.10)),
                            ),
                            child: Icon(
                              Icons.send,
                              color: Colors.white.withOpacity(0.85),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: iconRowHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: iconButtons,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
