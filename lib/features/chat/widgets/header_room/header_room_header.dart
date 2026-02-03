import 'package:flutter/material.dart';

/// Parte superior del HeaderRoom:
/// flecha + imagen placeholder + titulo + owner + icono info
class HeaderRoomHeader extends StatelessWidget {
  final String roomName;
  final String ownerText;

  final VoidCallback onBack;
  final VoidCallback onInfo;

  const HeaderRoomHeader({
    super.key,
    required this.roomName,
    required this.ownerText,
    required this.onBack,
    required this.onInfo,
  });

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
              Text(
                ownerText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
                overflow: TextOverflow.ellipsis,
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
