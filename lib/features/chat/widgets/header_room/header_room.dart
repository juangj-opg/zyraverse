import 'package:flutter/material.dart';

import '../../../profile/profile_screen.dart';
import 'header_room_header.dart';
import 'header_room_info.dart';

/// Fragmento 1/3 del chat: HeaderRoom
/// - header (back + imagen + titulo + owner + info)
/// - infoRoom (noticias + miembros + selector roleplay)
class HeaderRoom extends StatelessWidget {
  final String roomName;

  /// Puede ser null si el doc de la sala no tiene owner (seed antiguo / incompleto).
  final String? ownerUid;

  /// Mostrar nombre del owner (si no se conoce, se pone placeholder).
  final String ownerDisplayName;

  /// Se mantiene por compatibilidad, pero en UI se ignora (placeholder siempre).
  final String? ownerPhotoUrl;

  final int memberCount;

  final VoidCallback onBack;
  final VoidCallback onInfo;

  /// Si quieres sobreescribir la navegación, pásalo.
  final VoidCallback? onOwnerTap;

  const HeaderRoom({
    super.key,
    required this.roomName,
    required this.ownerUid,
    required this.ownerDisplayName,
    required this.ownerPhotoUrl,
    required this.memberCount,
    required this.onBack,
    required this.onInfo,
    this.onOwnerTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOwnerTap = onOwnerTap ??
        (ownerUid == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(profileUid: ownerUid!),
                  ),
                );
              });

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          HeaderRoomHeader(
            roomName: roomName,
            ownerUid: ownerUid,
            ownerDisplayName: ownerDisplayName,
            ownerPhotoUrl: ownerPhotoUrl,
            onBack: onBack,
            onInfo: onInfo,
            onOwnerTap: effectiveOwnerTap,
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
