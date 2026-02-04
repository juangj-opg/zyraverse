import 'package:flutter/material.dart';

/// Parte superior del HeaderRoom:
/// flecha + imagen placeholder + titulo + owner + icono info
class HeaderRoomHeader extends StatelessWidget {
  final String roomName;
  final String ownerDisplayName;
  final String? ownerPhotoUrl;

  final VoidCallback onBack;
  final VoidCallback onInfo;

  const HeaderRoomHeader({
    super.key,
    required this.roomName,
    required this.ownerDisplayName,
    required this.ownerPhotoUrl,
    required this.onBack,
    required this.onInfo,
  });

  Widget _ownerAvatar() {
    final url = (ownerPhotoUrl ?? '').trim();

    Widget fallback() {
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

    if (url.isEmpty) return fallback();

    return ClipOval(
      child: Image.network(
        url,
        width: 16,
        height: 16,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  _ownerAvatar(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ownerDisplayName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
