import 'package:flutter/material.dart';

/// Parte superior del HeaderRoom:
/// flecha + imagen placeholder + titulo + owner + icono info
///
/// - El bloque del owner (avatar + nombre) es clicable si [onOwnerTap] != null.
/// - Por privacidad/estilo (ProjectZ), NO se muestra photoURL real: avatar placeholder siempre.
///   (Se mantiene [ownerPhotoUrl] por compatibilidad, pero se ignora intencionalmente.)
class HeaderRoomHeader extends StatelessWidget {
  final String roomName;

  /// UID del owner para poder abrir su perfil (puede ser null si la sala está incompleta).
  final String? ownerUid;

  final String ownerDisplayName;

  /// Se mantiene por compatibilidad, pero se ignora (placeholder siempre).
  final String? ownerPhotoUrl;

  final VoidCallback onBack;
  final VoidCallback onInfo;

  /// Acción al pulsar sobre el owner (avatar o nombre).
  /// Si es null, no se podrá pulsar (fallback visual).
  final VoidCallback? onOwnerTap;

  const HeaderRoomHeader({
    super.key,
    required this.roomName,
    required this.ownerUid,
    required this.ownerDisplayName,
    required this.ownerPhotoUrl,
    required this.onBack,
    required this.onInfo,
    required this.onOwnerTap,
  });

  Widget _ownerAvatarPlaceholder() {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white10,
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          size: 12,
          color: Colors.white60,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canTapOwner = onOwnerTap != null && (ownerUid ?? '').trim().isNotEmpty;
    final ownerText = ownerDisplayName.trim().isEmpty ? '---' : ownerDisplayName;

    // ✅ SOLO icono + nombre, sin ocupar todo el ancho.
    Widget ownerInline = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ownerAvatarPlaceholder(),
        const SizedBox(width: 6),
        // Limitamos el ancho para que haga ellipsis sin necesitar Expanded.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            ownerText,
            style: TextStyle(
              fontSize: 12,
              color: canTapOwner ? Colors.white60 : Colors.white38,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );

    if (canTapOwner) {
      ownerInline = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onOwnerTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: ownerInline,
        ),
      );
    } else {
      ownerInline = Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ownerInline,
      );
    }

    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 6),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.image_outlined, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roomName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              ownerInline,
            ],
          ),
        ),
        IconButton(
          onPressed: onInfo,
          icon: const Icon(Icons.info_outline),
        ),
      ],
    );
  }
}
