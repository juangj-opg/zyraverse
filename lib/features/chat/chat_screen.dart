import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import '../rooms/room_model.dart';

import 'widgets/content_room.dart';
import 'widgets/header_room/header_room.dart';
import 'widgets/input_text_room/input_text_room.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final RoomsService _roomsService = RoomsService();
  final TextEditingController _controller = TextEditingController();

  late final DocumentReference<Map<String, dynamic>> _roomRef;
  late final CollectionReference<Map<String, dynamic>> _messagesRef;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;

  String? _myDisplayName;

  @override
  void initState() {
    super.initState();

    _roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.room.id);
    _messagesRef = _roomRef.collection('messages');

    _messagesStream = _messagesRef.orderBy('createdAt', descending: false).snapshots();

    _loadMyProfileSnapshot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final batch = FirebaseFirestore.instance.batch();

    final msgRef = _messagesRef.doc();
    batch.set(msgRef, {
      'type': 'user',
      'authorId': user.uid,
      'authorDisplayName': safeName,
      'text': text,
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

    final name = (_myDisplayName ?? '').trim();
    final safeName = name.isNotEmpty ? name : 'Usuario';

    // System message (compatible con reglas estrictas)
    await _messagesRef.add({
      'type': 'system',
      'authorId': '',
      'authorDisplayName': '',
      'text': '$safeName se ha unido a esta sala.',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _roomRef.set(
      {'lastActivityAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
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
            : ((roomData['memberIds'] is List) ? (roomData['memberIds'] as List).length : 0);

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
                    HeaderRoom(
                      roomName: roomName,
                      ownerText: ownerText,
                      memberCount: memberCount,
                      onBack: () => Navigator.pop(context),
                      onInfo: () {
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
                    ),
                    Expanded(
                      child: ContentRoom(
                        messagesStream: _messagesStream,
                        currentUid: uid,
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: InputTextRoom(
                          isMember: isMember,
                          controller: _controller,
                          onJoin: _joinRoom,
                          onSend: () => _sendMessage(isMember: true),
                        ),
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
}
