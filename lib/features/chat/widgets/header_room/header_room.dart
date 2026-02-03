import 'package:flutter/material.dart';

import 'header_room_header.dart';
import 'header_room_info.dart';

/// Fragmento 1/3 del chat: HeaderRoom
/// - header (back + imagen + titulo + owner + info)
/// - infoRoom (noticias + miembros + selector roleplay)
class HeaderRoom extends StatelessWidget {
  final String roomName;
  final String ownerText;
  final int memberCount;

  final VoidCallback onBack;
  final VoidCallback onInfo;

  const HeaderRoom({
    super.key,
    required this.roomName,
    required this.ownerText,
    required this.memberCount,
    required this.onBack,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          HeaderRoomHeader(
            roomName: roomName,
            ownerText: ownerText,
            onBack: onBack,
            onInfo: onInfo,
          ),
          const SizedBox(height: 10),
          HeaderRoomInfo(
            memberCount: memberCount,
          ),
        ],
      ),
    );
  }
}
