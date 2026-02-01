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

  static const double _avatarSize = 36;
  static const double _avatarGap = 10;

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

      if (username.isEmpty || displayName.isEmpty) return;

      await FirebaseFirestore.instance.collection('profiles').doc(uid).set(
        {
          'username': username,
          'displayName': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
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
    } catch (_) {}
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

                    final prevAuthorId =
                        index > 0 ? messages[index - 1].authorId : null;

                    final isFirstInGroup = prevAuthorId != msg.authorId;
                    final topPadding = isFirstInGroup ? 14.0 : 6.0;

                    final isMine = (myUid != null && msg.authorId == myUid);

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
                            avatar: _avatarPlaceholder(visible: isFirstInGroup),
                            reserveAvatarSpace: !isFirstInGroup,
                            avatarSize: _avatarSize,
                            avatarGap: _avatarGap,
                            showHeader: isFirstInGroup,
                            displayName: displayName,
                            content: msg.content,
                          );
                        },
                      ),
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

class _ProjectZMessageRow extends StatelessWidget {
  final bool isMine;

  final Widget avatar;
  final bool reserveAvatarSpace;
  final double avatarSize;
  final double avatarGap;

  final bool showHeader;
  final String displayName;
  final String content;

  const _ProjectZMessageRow({
    required this.isMine,
    required this.avatar,
    required this.reserveAvatarSpace,
    required this.avatarSize,
    required this.avatarGap,
    required this.showHeader,
    required this.displayName,
    required this.content,
  });

  static const double _bubbleRadius = 10; // ✅ antes 16 (más redondo)

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.white.withOpacity(0.08);

    final avatarSlot = reserveAvatarSpace
        ? SizedBox(width: avatarSize, height: avatarSize)
        : avatar;

    final bubbleDecoration = BoxDecoration(
      color: bubbleColor,
      borderRadius: BorderRadius.circular(_bubbleRadius),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    );

    // Otros (izquierda)
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: bubbleDecoration,
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 15, height: 1.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      );
    }

    // Tú (derecha)
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: bubbleDecoration,
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 15, height: 1.25),
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
