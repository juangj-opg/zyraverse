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
  final TextEditingController _controller = TextEditingController();

  final List<Message> _messages = [
    Message(
      id: '1',
      roomId: '1',
      authorId: 'user_1',
      content: '*entra en la sala y mira alrededor*',
      createdAt: DateTime.now(),
    ),
    Message(
      id: '2',
      roomId: '1',
      authorId: 'user_2',
      content: '— Bienvenido.',
      createdAt: DateTime.now(),
    ),
  ];

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().toString(),
          roomId: widget.room.id,
          authorId: 'debug_user',
          content: _controller.text,
          createdAt: DateTime.now(),
        ),
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
      ),
      body: Column(
        children: [
          // MENSAJES
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(msg.content),
                );
              },
            ),
          ),

          // INPUT
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
