import 'package:flutter/material.dart';

import '../../profile/profile_screen.dart';

class MessageGroupBubble extends StatelessWidget {
  final bool isMe;
  final String displayName;
  final String text;

  // ✅ Necesario para navegar al perfil correcto
  final String authorUid;

  final bool showHeader;
  final bool showAvatar;
  final bool addBottomGap;

  const MessageGroupBubble({
    super.key,
    required this.isMe,
    required this.displayName,
    required this.text,
    required this.authorUid,
    required this.showHeader,
    required this.showAvatar,
    required this.addBottomGap,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.white10;

    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final rowAlign = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    void openProfile() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(profileUid: authorUid),
        ),
      );
    }

    Widget buildAvatar() {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: openProfile,
        child: const CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(Icons.person, color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: addBottomGap ? 14 : 6),
      child: Row(
        mainAxisAlignment: rowAlign,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && showAvatar) ...[
            buildAvatar(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(text),
                ),
              ],
            ),
          ),
          if (isMe && showAvatar) ...[
            const SizedBox(width: 10),
            buildAvatar(),
          ] else if (isMe) ...[
            const SizedBox(width: 10),
            const SizedBox(width: 40),
          ],
        ],
      ),
    );
  }
}
