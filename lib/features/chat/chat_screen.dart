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

      // si no está completo, no tocamos nada
      if (username.isEmpty || displayName.isEmpty) return;

      // ✅ Creamos/actualizamos perfil público SIN photoURL (y borramos si existía)
      await FirebaseFirestore.instance.collection('profiles').doc(uid).set(
        {
          'username': username,
          'displayName': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
          'photoURL': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );

      // Cache para que no salga "Usuario"
      _profileCache[uid] = PublicProfile(
        uid: uid,
        username: username,
        displayName: displayName,
        photoURL: null,
      );
    } catch (_) {
      // si falla, caerá al fallback "Usuario"
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

  String _formatTime(DateTime dt) {
    final local = dt.toLocal(); // ✅ evita desfases típicos
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef.orderBy('createdAt', descending: false).snapshots(),
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
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = myUid != null && msg.authorId == myUid;

                    return FutureBuilder<PublicProfile?>(
                      future: _loadProfile(msg.authorId),
                      builder: (context, profSnap) {
                        final profile = profSnap.data;

                        final displayName =
                            (profile?.displayName.isNotEmpty == true)
                                ? profile!.displayName
                                : 'Usuario';

                        final username =
                            (profile?.username.isNotEmpty == true)
                                ? '@${profile!.username}'
                                : '';

                        final timeText = msg.createdAt.millisecondsSinceEpoch == 0
                            ? ''
                            : _formatTime(msg.createdAt);

                        return _MessageTile(
                          isMine: isMine,
                          displayName: displayName,
                          username: username,
                          content: msg.content,
                          timeText: timeText,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      contentPadding: EdgeInsets.all(12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final bool isMine;
  final String displayName;
  final String username;
  final String content;
  final String timeText;

  const _MessageTile({
    required this.isMine,
    required this.displayName,
    required this.username,
    required this.content,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
        : Colors.white.withOpacity(0.08);

    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final cross = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // ✅ Avatar estilo “placeholder” (sin foto de Google)
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white.withOpacity(0.08),
      child: Icon(
        Icons.person,
        size: 18,
        color: Colors.white.withOpacity(0.85),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            crossAxisAlignment: cross,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine) avatar,
                  if (!isMine) const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: cross,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (timeText.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                timeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (username.isNotEmpty)
                          Text(
                            username,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isMine) const SizedBox(width: 10),
                  if (isMine) avatar,
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 15, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
