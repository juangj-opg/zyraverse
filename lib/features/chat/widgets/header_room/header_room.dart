import 'package:flutter/material.dart';

import 'header_room_header.dart';
import 'header_room_info.dart';

/// Fragmento 1/3 del chat: HeaderRoom
/// - header (back + imagen + titulo + owner + info)
/// - infoRoom (noticias + miembros + selector roleplay)
class HeaderRoom extends StatelessWidget {
  final String roomName;
  final String ownerDisplayName;
  final String? ownerPhotoUrl;
  final int memberCount;

  final VoidCallback onBack;
  final VoidCallback onInfo;

  const HeaderRoom({
    super.key,
    required this.roomName,
    required this.ownerDisplayName,
    required this.ownerPhotoUrl,
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
            ownerDisplayName: ownerDisplayName,
            ownerPhotoUrl: ownerPhotoUrl,
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
